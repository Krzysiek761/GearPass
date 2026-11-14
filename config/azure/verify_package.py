import asyncio
import json
import os
from pathlib import Path
import sys
from types import SimpleNamespace

release = Path("release")
api = release / "api"
web = release / "web"
sys.path[:0] = [str(api.resolve()), str((api / ".python_packages/lib/site-packages").resolve())]

import azure.functions as func
from GearPassHttp import main


def check(condition, message):
    if not condition:
        raise SystemExit(message)
    print(message + " [OK]", flush=True)


async def request(path, method="GET", body=b""):
    req = func.HttpRequest(
        method=method,
        url="https://localhost/api/" + path,
        headers={"Content-Type": "application/json"},
        body=body,
    )
    context = SimpleNamespace(
        invocation_id="ci", function_name="GearPassHttp", function_directory=str(api),
        trace_context=None, retry_context=None, thread_local_storage=None,
    )
    response = await main(req, context)
    return response.status_code, json.loads(response.get_body())


async def verify():
    commit = os.environ["GITHUB_SHA"]
    check('id="root"' in (web / "index.html").read_text(encoding="utf-8"), "Static frontend built")
    check(any((web / "assets").glob("*.js")), "Vite JavaScript bundle present")
    check(json.loads((web / "version.json").read_text()) == {"commit": commit}, "Frontend commit matches")
    check(await request("health") == (200, {"status": "ok", "commit": commit}), "Azure Functions adapter: GET /api/health reports the commit")

    status, equipment = await request("equipment")
    check(status == 200 and isinstance(equipment, list) and len(equipment) > 0, "Azure Functions adapter: GET /api/equipment returns data")
    status, _ = await request("equipment", "POST", b'{"name":"x","category":"Foto"}')
    check(status == 422, "Azure Functions adapter: POST /api/equipment validates data")
    print("Verified commit " + commit)


if __name__ == "__main__":
    asyncio.run(verify())
