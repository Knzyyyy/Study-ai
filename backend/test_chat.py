import asyncio
import importlib
import sys
import unittest
from types import ModuleType, SimpleNamespace
from unittest.mock import MagicMock, patch
from fastapi import HTTPException


class ChatTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        modules = {}
        for name, attributes in {
            "app.auth": {"get_current_user": MagicMock()},
            "app.services.supabase_client": {"supabase": MagicMock()},
            "app.services.ai_service": {"get_chat_stream": MagicMock()},
        }.items():
            module = ModuleType(name)
            module.__dict__.update(attributes)
            modules[name] = module
        cls.modules = patch.dict(sys.modules, modules)
        cls.modules.start()
        cls.router = importlib.import_module("app.routers.chat")

    @classmethod
    def tearDownClass(cls):
        sys.modules.pop("app.routers.chat", None)
        cls.modules.stop()

    def setUp(self):
        self.db = MagicMock()
        self.query = self.db.table.return_value
        for method in ("select", "eq", "order", "limit", "insert"):
            getattr(self.query, method).return_value = self.query
        self.user = SimpleNamespace(id="owner")
        self.db_patch = patch.object(self.router, "supabase", self.db)
        self.db_patch.start()
        self.addCleanup(self.db_patch.stop)

    def test_foreign_material_blocks_listing_and_creation(self):
        self.query.execute.return_value.data = []
        for action in (
            lambda: self.router.list_chat_sessions("foreign", self.user),
            lambda: self.router.create_chat_session(self.router.CreateSessionRequest(material_id="foreign"), self.user),
        ):
            with self.assertRaises(HTTPException):
                action()
        self.query.insert.assert_not_called()
        self.assertNotIn("chat_sessions", [c.args[0] for c in self.db.table.call_args_list])
        self.query.eq.assert_any_call("user_id", "owner")

    def test_foreign_session_blocks_messages_and_send(self):
        self.query.execute.return_value.data = []
        for action in (
            lambda: self.router.get_chat_messages("foreign", self.user),
            lambda: self.router.send_message_stream("foreign", self.router.SendMessageRequest(content="hello"), self.user),
        ):
            with self.assertRaises(HTTPException):
                action()
        self.assertNotIn("chat_messages", [c.args[0] for c in self.db.table.call_args_list])

    def test_history_title_and_latest_use_message_fields(self):
        self.query.execute.side_effect = [
            SimpleNamespace(data=[{"id": "material"}]),
            SimpleNamespace(data=[{"id": "empty"}, {"id": "old"}, {"id": "latest"}]),
            SimpleNamespace(data=[]),
            SimpleNamespace(data=[{"role": "user", "content": "First question", "created_at": "2026-01-01T00:00:00Z"}]),
            SimpleNamespace(data=[{"role": "user", "content": "Latest question", "created_at": "2026-02-01T00:00:00Z"}]),
        ]
        sessions = self.router.list_chat_sessions("material", self.user)
        self.assertEqual([s["id"] for s in sessions], ["latest", "old", "empty"])
        self.assertEqual(sessions[0]["title"], "Latest question")
        self.assertIsNone(sessions[-1]["last_message_at"])
        self.query.eq.assert_any_call("material_id", "material")
        self.query.eq.assert_any_call("user_id", "owner")

    def test_owned_session_with_foreign_material_blocks_read(self):
        self.query.execute.side_effect = [
            SimpleNamespace(data=[{"material_id": "foreign"}]),
            SimpleNamespace(data=[]),
        ]
        with self.assertRaises(HTTPException):
            self.router.get_chat_messages("session", self.user)
        self.assertNotIn("chat_messages", [c.args[0] for c in self.db.table.call_args_list])

    def test_partial_saved_before_terminal_error(self):
        self.query.execute.return_value.data = [{"material_id": "material", "overview": "context", "sections": [], "role": "user", "content": "previous"}]

        def broken(*args):
            yield "partial"
            raise RuntimeError("private provider details")

        async def collect(response):
            return [event async for event in response.body_iterator]

        with patch.object(self.router, "get_chat_stream", side_effect=broken):
            response = self.router.send_message_stream("session", self.router.SendMessageRequest(content="hello"), self.user)
            events = asyncio.run(collect(response))
        self.assertIn('"error"', events[-1])
        self.assertNotIn("private provider", events[-1])
        self.query.insert.assert_any_call({"session_id": "session", "role": "assistant", "content": "partial"})


if __name__ == "__main__":
    unittest.main()
