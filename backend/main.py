from fastapi import FastAPI, HTTPException
from models import Equipment

app = FastAPI(title="GearPass API")

@app.get("/api/equipment", status_code=200)
def get_all_equipment():
    return [{"id": 1, "name": "Aparat Sony A7 III", "status": "Dostępny"}]

@app.post("/api/equipment", status_code=201)
def create_equipment(item: Equipment):
    if item.name == "error":
        raise HTTPException(status_code=400, detail="Błąd walidacji danych")
    return {"message": "Utworzono pomyślnie", "data": item}

@app.put("/api/equipment/{item_id}", status_code=200)
def update_equipment(item_id: int, item: Equipment):
    return {"id": item_id, "updated_data": item}

@app.delete("/api/equipment/{item_id}", status_code=200)
def delete_equipment(item_id: int):
    if item_id > 100:
        raise HTTPException(status_code=404, detail="Sprzęt nie istnieje")
    return {"message": f"Usunięto sprzęt {item_id}"}