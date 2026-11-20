import json
import logging
import sys
import time
from datetime import datetime, timezone
import os
import secrets
from contextlib import closing
from pathlib import Path

import psycopg2
from fastapi import FastAPI, Header, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse
from psycopg2.extras import RealDictCursor

from models import Equipment

app = FastAPI(title="GearPass API")
request_logger = logging.getLogger("gearpass.requests")
if not request_logger.handlers:
    request_logger.addHandler(logging.StreamHandler(sys.stdout))
request_logger.setLevel(logging.INFO)
request_logger.propagate = False


@app.middleware("http")
async def record_http_request(request, call_next):
    started = time.perf_counter()
    status_code = 500
    try:
        response = await call_next(request)
        status_code = response.status_code
        return response
    finally:
        route = request.scope.get("route")
        request_logger.info(json.dumps({
            "event": "http_request",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "method": request.method,
            "route": getattr(route, "path", "unmatched"),
            "status_code": status_code,
            "duration_ms": round((time.perf_counter() - started) * 1000, 3),
        }))

RELEASE_VERSION = Path(__file__).with_name("version.json")
DATABASE_DSN = os.environ.get("GEARPASS_DB_DSN")
WRITE_KEY = os.environ.get("GEARPASS_WRITE_KEY")

if DATABASE_DSN and not WRITE_KEY:
    raise RuntimeError("GEARPASS_WRITE_KEY is required when PostgreSQL is enabled")


def query(statement, parameters=(), *, many=False):
    try:
        with closing(psycopg2.connect(DATABASE_DSN, connect_timeout=3, options="-c statement_timeout=3000")) as connection:
            with connection, connection.cursor(cursor_factory=RealDictCursor) as cursor:
                cursor.execute(statement, parameters)
                return cursor.fetchall() if many else cursor.fetchone()
    except psycopg2.Error as exc:
        raise HTTPException(status_code=503, detail="Baza danych jest niedostępna") from exc


def require_writer(key):
    if not key or not secrets.compare_digest(key.encode("utf-8"), WRITE_KEY.encode("utf-8")):
        raise HTTPException(status_code=403, detail="Wymagany prawidłowy klucz zapisu")


@app.get("/health", include_in_schema=False)
def readiness():
    headers = {"Cache-Control": "no-store"}
    if not DATABASE_DSN:
        return JSONResponse(
            {"status": "DOWN", "database": "NOT_CONFIGURED"},
            status_code=503,
            headers=headers,
        )
    try:
        query("SELECT 1")
    except HTTPException as exc:
        if exc.status_code != 503:
            raise
        return JSONResponse(
            {"status": "DOWN", "database": "DOWN"},
            status_code=503,
            headers=headers,
        )
    return JSONResponse({"status": "UP", "database": "UP"}, headers=headers)


@app.get("/api/health")
def health():
    commit = json.loads(RELEASE_VERSION.read_text(encoding="utf-8"))["commit"] if RELEASE_VERSION.is_file() else "local"
    status = {"status": "ok", "commit": commit}
    if DATABASE_DSN:
        query("SELECT 1")
        status["storage"] = "postgresql"
    return status


@app.get("/api/equipment", status_code=200)
def get_all_equipment():
    if DATABASE_DSN:
        return query("SELECT id, name, category, status FROM equipment ORDER BY id", many=True)
    return [{"id": 1, "name": "Aparat Sony A7 III", "status": "Dostępny"}]


@app.post("/api/equipment", status_code=201)
def create_equipment(item: Equipment, key: str | None = Header(None, alias="X-GearPass-Key")):
    if DATABASE_DSN:
        require_writer(key)
    if item.name == "error":
        raise HTTPException(status_code=400, detail="Błąd walidacji danych")
    if DATABASE_DSN:
        row = query(
            "INSERT INTO equipment (name, category, status) VALUES (%s, %s, %s) "
            "RETURNING id, name, category, status",
            (item.name, item.category, item.status),
        )
        return {"message": "Utworzono pomyślnie", "data": row}
    return {"message": "Utworzono pomyślnie", "data": item}


@app.put("/api/equipment/{item_id}", status_code=200)
def update_equipment(item_id: int, item: Equipment, key: str | None = Header(None, alias="X-GearPass-Key")):
    if DATABASE_DSN:
        require_writer(key)
        row = query(
            "UPDATE equipment SET name = %s, category = %s, status = %s WHERE id = %s "
            "RETURNING id, name, category, status",
            (item.name, item.category, item.status, item_id),
        )
        if row is None:
            raise HTTPException(status_code=404, detail="Sprzęt nie istnieje")
        return {"id": item_id, "updated_data": row}
    return {"id": item_id, "updated_data": item}


@app.delete("/api/equipment/{item_id}", status_code=200)
def delete_equipment(item_id: int, key: str | None = Header(None, alias="X-GearPass-Key")):
    if DATABASE_DSN:
        require_writer(key)
        row = query("DELETE FROM equipment WHERE id = %s RETURNING id", (item_id,))
        if row is None:
            raise HTTPException(status_code=404, detail="Sprzęt nie istnieje")
    elif item_id > 100:
        raise HTTPException(status_code=404, detail="Sprzęt nie istnieje")
    return {"message": f"Usunięto sprzęt {item_id}"}


# App Service serves the bundled frontend. The private deployment serves it from its Web VM.
STATIC_ROOT = Path(__file__).with_name("static")
if STATIC_ROOT.is_dir():
    app.mount("/", StaticFiles(directory=STATIC_ROOT, html=True), name="web")
