import importlib
import itertools
import sys
import unittest
from types import ModuleType, SimpleNamespace
from unittest.mock import MagicMock, patch

from fastapi import BackgroundTasks
from pydantic import ValidationError


class MaterialOptionsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        modules = {}
        for name, attributes in {
            "app.auth": {"get_current_user": MagicMock()},
            "app.services.supabase_client": {"supabase": MagicMock()},
            "app.services.extractor": {
                "extract_text_from_pdf": MagicMock(),
                "extract_text_from_pptx": MagicMock(),
            },
            "app.services.summarizer": {"process_material_text": MagicMock()},
            "app.services.ai_service": {
                "MODEL": "test-model",
                "generate_flashcards": MagicMock(),
                "generate_quiz_questions": MagicMock(),
            },
        }.items():
            module = ModuleType(name)
            module.__dict__.update(attributes)
            modules[name] = module
        cls.module_patch = patch.dict(sys.modules, modules)
        cls.module_patch.start()
        cls.router = importlib.import_module("app.routers.materials")

    @classmethod
    def tearDownClass(cls):
        sys.modules.pop("app.routers.materials", None)
        cls.module_patch.stop()

    def test_defaults_and_validation(self):
        options = self.router.ProcessMaterialRequest()
        self.assertEqual(options.model_dump(), {
            "generate_summary": True,
            "generate_flashcards": False,
            "generate_quiz": False,
        })
        for field in options.model_dump():
            for invalid in ("false", 1, None):
                with self.assertRaises(ValidationError):
                    self.router.ProcessMaterialRequest(**{field: invalid})
        with self.assertRaises(ValidationError):
            self.router.ProcessMaterialRequest(unknown=True)
        tasks = BackgroundTasks()
        db = MagicMock()
        db.table.return_value.select.return_value.eq.return_value.eq.return_value.execute.return_value.data = [{"status": "uploaded"}]
        with patch.object(self.router, "supabase", db):
            self.router.trigger_process_material("material", tasks, user=SimpleNamespace(id="user"))
        self.assertEqual(tasks.tasks[0].args, ("material", "user", options))

    def test_duplicate_jobs_and_lost_claim(self):
        for status, claimed in (("processing", True), ("done", True), ("failed", False)):
            with self.subTest(status=status):
                db = MagicMock()
                db.table.return_value.select.return_value.eq.return_value.eq.return_value.execute.return_value.data = [{"status": status}]
                db.table.return_value.update.return_value.eq.return_value.eq.return_value.eq.return_value.execute.return_value.data = [{"id": "material"}] if claimed else []
                tasks = BackgroundTasks()
                with patch.object(self.router, "supabase", db):
                    self.router.trigger_process_material("material", tasks, user=SimpleNamespace(id="user"))
                self.assertEqual(tasks.tasks, [])

    def test_retry_preserves_existing_outputs(self):
        r = self.router
        db = MagicMock()
        db.table.return_value.select.return_value.eq.return_value.eq.return_value.execute.return_value.data = [{"status": "processing", "file_path": "file.pdf", "file_type": "pdf"}]
        db.table.return_value.select.return_value.eq.return_value.execute.return_value.data = [{"id": "existing", "page_number": 1}]
        db.storage.from_.return_value.download.return_value = b"pdf"
        with patch.object(r, "supabase", db), patch.object(r, "extract_text_from_pdf", return_value=[{"page_number": 1, "content_text": "Source"}]), patch.object(r, "process_material_text") as summary, patch.object(r, "generate_flashcards") as cards, patch.object(r, "generate_quiz_questions") as quiz:
            r.process_material_background("material", "user", r.ProcessMaterialRequest(generate_flashcards=True, generate_quiz=True))
        summary.assert_not_called()
        cards.assert_not_called()
        quiz.assert_not_called()
        db.table.return_value.insert.assert_not_called()
        db.table.return_value.delete.assert_not_called()

    def test_all_option_combinations(self):
        r = self.router
        for summary, flashcards, quiz in itertools.product((False, True), repeat=3):
            with self.subTest(summary=summary, flashcards=flashcards, quiz=quiz):
                db = MagicMock()
                db.table.return_value.select.return_value.eq.return_value.eq.return_value.execute.return_value.data = [{
                    "file_path": "file.pdf", "file_type": "pdf", "status": "processing",
                }]
                db.table.return_value.select.return_value.eq.return_value.execute.return_value.data = []
                db.storage.from_.return_value.download.return_value = b"pdf"
                db.table.return_value.insert.return_value.execute.return_value.data = [{"id": "quiz"}]
                pages = [{"page_number": 1, "content_text": "Extracted source"}]
                with patch.object(r, "supabase", db), patch.object(r, "extract_text_from_pdf", return_value=pages), patch.object(r, "process_material_text", return_value={"overview": "Overview", "sections": [], "key_terms": []}) as summarize, patch.object(r, "generate_flashcards", return_value=[{"front": "Q", "back": "A"}]) as cards, patch.object(r, "generate_quiz_questions", return_value=[{"question": "Q"}]) as questions:
                    r.process_material_background("material", "user", r.ProcessMaterialRequest(
                        generate_summary=summary, generate_flashcards=flashcards, generate_quiz=quiz,
                    ))
                self.assertEqual(summarize.call_count, int(summary))
                self.assertEqual(cards.call_count, int(flashcards))
                self.assertEqual(questions.call_count, int(quiz))
                if flashcards:
                    cards.assert_called_once_with("Extracted source")
                if quiz:
                    questions.assert_called_once_with("Extracted source", 10, "medium")
                tables = [call.args[0] for call in db.table.call_args_list]
                self.assertIn("material_pages", tables)
                self.assertEqual("summaries" in tables, summary)
                self.assertEqual("flashcards" in tables, flashcards)
                self.assertEqual("quizzes" in tables, quiz)
                self.assertEqual("quiz_questions" in tables, quiz)
                updates = [call.args[0] for call in db.table.return_value.update.call_args_list]
                self.assertEqual(updates[-1]["status"], "done")


if __name__ == "__main__":
    unittest.main()
