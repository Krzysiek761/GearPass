from pydantic import BaseModel, Field

class Equipment(BaseModel):
    name: str = Field(..., min_length=2, description="Nazwa sprzętu")
    category: str = Field(..., description="Kategoria, np. Foto, VR")
    status: str = Field(default="Dostępny")