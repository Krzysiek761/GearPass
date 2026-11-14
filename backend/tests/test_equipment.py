import unittest

from fastapi.testclient import TestClient

from main import app


class EquipmentTests(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)
        self.addCleanup(self.client.close)

    def test_list_equipment(self):
        response = self.client.get("/api/equipment")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()[0]["name"], "Aparat Sony A7 III")

    def test_create_equipment(self):
        response = self.client.post(
            "/api/equipment",
            json={"name": "Kamera", "category": "Foto"},
        )
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.json()["data"]["status"], "Dostępny")

    def test_reject_invalid_equipment(self):
        response = self.client.post(
            "/api/equipment",
            json={"name": "A", "category": "Foto"},
        )
        self.assertEqual(response.status_code, 422)
