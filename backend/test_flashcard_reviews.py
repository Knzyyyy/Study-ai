import importlib
import sys
import unittest
from types import ModuleType, SimpleNamespace
from unittest.mock import MagicMock, patch
from uuid import UUID

from fastapi import HTTPException


class FlashcardReviewsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        modules = {}
        for name, attributes in {
            "app.auth": {"get_current_user": MagicMock()},
            "app.services.supabase_client": {"supabase": MagicMock()},
            "app.services.ai_service": {"generate_flashcards": MagicMock()},
        }.items():
            module = ModuleType(name)
            module.__dict__.update(attributes)
            modules[name] = module
        cls.modules = patch.dict(sys.modules, modules)
        cls.modules.start()
        cls.router = importlib.import_module("app.routers.flashcards")

    @classmethod
    def tearDownClass(cls):
        sys.modules.pop("app.routers.flashcards", None)
        cls.modules.stop()

    def test_mark_is_idempotent_and_scoped_to_owner(self):
        db = MagicMock()
        db.table.return_value.select.return_value.eq.return_value.eq.return_value.execute.return_value.data = [{"id": "owned"}]
        material = UUID(int=1)
        card = UUID(int=2)
        with patch.object(self.router, "supabase", db):
            for _ in range(2):
                self.assertEqual(self.router.mark_flashcard_studied(material, card, SimpleNamespace(id="user")), {"studied": True})
        db.table.return_value.upsert.assert_called_with(
            {"user_id": "user", "flashcard_id": str(card), "material_id": str(material)},
            on_conflict="user_id,flashcard_id", ignore_duplicates=True,
        )
        db.table.return_value.select.return_value.eq.return_value.eq.assert_any_call("user_id", "user")
        db.table.return_value.select.return_value.eq.return_value.eq.assert_any_call("material_id", str(material))

    def test_missing_or_foreign_material_and_card_rejected(self):
        for responses in ([], [{"id": "owned"}]):
            db = MagicMock()
            query = db.table.return_value.select.return_value.eq.return_value.eq.return_value.execute
            query.side_effect = [SimpleNamespace(data=responses), SimpleNamespace(data=[])]
            with patch.object(self.router, "supabase", db), self.assertRaises(HTTPException) as error:
                self.router.mark_flashcard_studied(UUID(int=1), UUID(int=2), SimpleNamespace(id="user"))
            self.assertEqual(error.exception.status_code, 404)
            db.table.return_value.upsert.assert_not_called()

    def test_count_uses_authenticated_user(self):
        db = MagicMock()
        db.table.return_value.select.return_value.eq.return_value.execute.return_value.count = 7
        with patch.object(self.router, "supabase", db):
            self.assertEqual(self.router.get_flashcard_review_count(SimpleNamespace(id="user")), {"count": 7})
        db.table.return_value.select.assert_called_once_with("flashcard_id", count="exact", head=True)
        db.table.return_value.select.return_value.eq.assert_called_once_with("user_id", "user")


if __name__ == "__main__":
    unittest.main()
