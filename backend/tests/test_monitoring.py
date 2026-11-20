import json
import unittest
from unittest.mock import patch

from fastapi import HTTPException
from fastapi.testclient import TestClient

import main


class MonitoringTests(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(main.app)

    def test_health_checks_database(self):
        with patch.object(main, "DATABASE_DSN", "configured"), patch.object(main, "query") as query:
            response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "UP")
        self.assertEqual(response.json()["database"], "UP")
        query.assert_called_once_with("SELECT 1")

    def test_database_failure_returns_down_without_exception_details(self):
        with patch.object(main, "DATABASE_DSN", "configured"), patch.object(
            main, "query", side_effect=HTTPException(503, "private connection string")
        ):
            response = self.client.get("/health")
        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.json(), {"status": "DOWN", "database": "DOWN"})
        self.assertNotIn("private", response.text)

    def test_missing_database_does_not_report_up(self):
        with patch.object(main, "DATABASE_DSN", None):
            response = self.client.get("/health")
        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.json()["database"], "NOT_CONFIGURED")

    def test_legacy_health_contract_is_preserved(self):
        with patch.object(main, "DATABASE_DSN", None):
            response = self.client.get("/api/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "ok")
        self.assertIn("commit", response.json())

    def test_http_event_has_latency_and_status_without_sensitive_input(self):
        with self.assertLogs("gearpass.requests", level="INFO") as captured:
            self.client.get("/api/equipment?token=secret-value", headers={"X-GearPass-Key": "secret-value"})
        event = json.loads(captured.records[-1].getMessage())
        self.assertEqual(event["event"], "http_request")
        self.assertEqual(event["status_code"], 200)
        self.assertEqual(event["route"], "/api/equipment")
        self.assertGreaterEqual(event["duration_ms"], 0)
        self.assertNotIn("secret-value", captured.records[-1].getMessage())

    def test_unknown_path_is_not_logged_as_user_supplied_text(self):
        with self.assertLogs("gearpass.requests", level="INFO") as captured:
            self.client.get("/secret-value")
        event = json.loads(captured.records[-1].getMessage())
        self.assertEqual(event["status_code"], 404)
        self.assertEqual(event["route"], "unmatched")


if __name__ == "__main__":
    unittest.main()
