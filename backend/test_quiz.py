import importlib
import sys
import unittest
from types import ModuleType, SimpleNamespace
from unittest.mock import MagicMock, patch
from fastapi import HTTPException
from app.schemas.quiz import GenerateQuizRequest, SubmitQuizRequest


class QuizTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        modules = {}
        for name, attrs in {
            "app.auth": {"get_current_user": MagicMock()},
            "app.services.supabase_client": {"supabase": MagicMock()},
            "app.services.ai_service": {"generate_quiz_questions": MagicMock()},
        }.items():
            module = ModuleType(name)
            module.__dict__.update(attrs)
            modules[name] = module
        cls.patcher = patch.dict(sys.modules, modules)
        cls.patcher.start()
        cls.router = importlib.import_module("app.routers.quiz")

    @classmethod
    def tearDownClass(cls):
        sys.modules.pop("app.routers.quiz", None)
        cls.patcher.stop()

    def database(self, results):
        db = MagicMock()
        query = db.table.return_value
        for method in ("select", "eq", "in_", "order", "insert", "delete", "range"):
            getattr(query, method).return_value = query
        query.execute.side_effect = [SimpleNamespace(data=data) for data in results]
        return db

    def test_discovery_owned_and_no_keys(self):
        db = self.database([[{"id": "m"}], [{"id": "q", "material_id": "m", "title": "Quiz"}], [{"id": "x", "question": "Q", "options": ["A", "B"]}]])
        with patch.object(self.router, "supabase", db):
            result = self.router.find_material_quiz("m", SimpleNamespace(id="u"))
        self.assertEqual(result["quiz"]["id"], "q")
        self.assertNotIn("correct_index", result["questions"][0])
        db.table.return_value.select.assert_any_call("id, question, options")
        db.table.return_value.order.assert_any_call("id", desc=True)
        db.table.return_value.eq.assert_any_call("user_id", "u")

    def test_discovery_foreign_and_missing(self):
        db = self.database([[]])
        with patch.object(self.router, "supabase", db), self.assertRaises(HTTPException):
            self.router.find_material_quiz("m", SimpleNamespace(id="u"))
        self.assertEqual([c.args[0] for c in db.table.call_args_list], ["materials"])
        db = self.database([[{"id": "m"}], []])
        with patch.object(self.router, "supabase", db):
            self.assertIsNone(self.router.find_material_quiz("m", SimpleNamespace(id="u"))["quiz"])

    def test_generate_without_summary(self):
        question = {"question": "Q", "options": ["A", "B", "C", "D"], "correct_index": 0, "explanation": "Because"}
        db = self.database([[{"id": "m"}], [], [{"content_text": "Extracted source"}], [{"id": "q"}], []])
        with patch.object(self.router, "supabase", db), patch.object(self.router, "generate_quiz_questions", return_value=[question]) as generate:
            result = self.router.create_quiz("m", GenerateQuizRequest(amount=1), SimpleNamespace(id="u"))
        self.assertEqual(result["quiz_id"], "q")
        generate.assert_called_once_with("Extracted source", 1, "sedang")
        db.table.return_value.order.assert_any_call("page_number")

    def test_generate_without_text(self):
        db = self.database([[{"id": "m"}], [], [{"content_text": "  "}]])
        with patch.object(self.router, "supabase", db), patch.object(self.router, "generate_quiz_questions") as generate, self.assertRaises(HTTPException) as error:
            self.router.create_quiz("m", GenerateQuizRequest(), SimpleNamespace(id="u"))
        self.assertEqual(error.exception.status_code, 400)
        generate.assert_not_called()

    def test_progress_aggregation_and_unknown_dates(self):
        aggregate = self.router.progress_for_attempts
        self.assertEqual(aggregate([]), {
            "count": 0, "mean_score": None, "best_score": None,
            "latest_score": None, "last_practiced_at": None,
        })
        attempts = [
            {"score": 40, "created_at": "2026-01-01T00:00:00Z"},
            {"score": 80, "created_at": "2026-02-01T00:00:00+00:00"},
        ]
        result = aggregate(attempts)
        self.assertEqual((result["mean_score"], result["best_score"], result["latest_score"]), (60, 80, 80))
        self.assertEqual(result["count"], 2)
        attempts.append({"score": 100, "created_at": None})
        result = aggregate(attempts)
        self.assertIsNone(result["latest_score"])
        self.assertEqual(result["best_score"], 100)
        self.assertEqual(result["last_practiced_at"], "2026-02-01T00:00:00+00:00")
        self.assertIsNone(aggregate([{"score": 0, "created_at": None}])["last_practiced_at"])
        self.assertIsNone(aggregate(attempts[:2] + [attempts[1]])["latest_score"])

    def test_bulk_progress_scopes_ownership_and_attempt_user(self):
        db = self.database([
            [{"id": "m"}, {"id": "untested"}],
            [{"id": "q", "material_id": "m"}, {"id": "q2", "material_id": "m"}],
            [{"id": "a", "quiz_id": "q", "score": 50, "created_at": None},
             {"id": "b", "quiz_id": "q2", "score": 100, "created_at": None}],
        ])
        with patch.object(self.router, "supabase", db):
            result = self.router.list_material_progress(SimpleNamespace(id="u"))["progress"]
        self.assertEqual(result["m"]["mean_score"], 75)
        self.assertEqual(result["untested"]["count"], 0)
        self.assertEqual(db.table.return_value.eq.call_args_list.count(unittest.mock.call("user_id", "u")), 2)
        db.table.return_value.in_.assert_any_call("material_id", ["m", "untested"])
        db.table.return_value.in_.assert_any_call("quiz_id", ["q", "q2"])
        self.assertEqual(db.table.call_count, 3)

    def test_progress_foreign_material_stops_before_history(self):
        db = self.database([[]])
        with patch.object(self.router, "supabase", db), self.assertRaises(HTTPException) as error:
            self.router.get_material_progress("foreign", SimpleNamespace(id="u"))
        self.assertEqual(error.exception.status_code, 404)
        self.assertEqual(db.table.call_count, 1)
        db.table.return_value.eq.assert_any_call("user_id", "u")

    def test_default(self):
        self.assertEqual(GenerateQuizRequest().amount, 10)

    def test_foreign_quiz_cannot_read_or_submit(self):
        for action in (
            lambda: self.router.get_quiz_questions("q", SimpleNamespace(id="u")),
            lambda: self.router.submit_quiz_attempt("q", SubmitQuizRequest(answers=[{"question_id": "x", "selected_index": 0}]), SimpleNamespace(id="u")),
        ):
            db = self.database([[{"id": "q", "material_id": "m", "title": "Quiz"}], []])
            with patch.object(self.router, "supabase", db), self.assertRaises(HTTPException) as error:
                action()
            self.assertEqual(error.exception.status_code, 404)
            self.assertNotIn("quiz_questions", [c.args[0] for c in db.table.call_args_list])

    def test_foreign_attempt_and_material(self):
        for action in (
            lambda: self.router.get_attempt_review("a", SimpleNamespace(id="u")),
            lambda: self.router.list_quiz_attempts("m", SimpleNamespace(id="u")),
        ):
            db = self.database([[]])
            with patch.object(self.router, "supabase", db), self.assertRaises(HTTPException):
                action()
            db.table.return_value.eq.assert_any_call("user_id", "u")

    def test_review(self):
        db = self.database([
            [{"id": "a", "quiz_id": "q", "score": 0, "created_at": "2026-01-01"}],
            [{"id": "q", "material_id": "m", "title": "Quiz"}], [{"id": "m"}],
            [{"id": "x", "question": "Q", "options": ["A", "B"], "correct_index": 1, "explanation": "Because"}],
            [{"question_id": "x", "selected_index": 0}],
        ])
        with patch.object(self.router, "supabase", db):
            review = self.router.get_attempt_review("a", SimpleNamespace(id="u"))
        self.assertEqual(review["questions"][0]["selected_index"], 0)
        self.assertEqual(review["questions"][0]["correct_index"], 1)
        self.assertEqual(review["questions"][0]["explanation"], "Because")

    def test_duplicate_answers_rejected(self):
        db = self.database([[{"id": "q", "material_id": "m", "title": "Quiz"}], [{"id": "m"}], [{"id": "x", "options": ["A", "B"], "correct_index": 0}]])
        req = SubmitQuizRequest(answers=[{"question_id": "x", "selected_index": 0}] * 2)
        with patch.object(self.router, "supabase", db), self.assertRaises(HTTPException) as error:
            self.router.submit_quiz_attempt("q", req, SimpleNamespace(id="u"))
        self.assertEqual(error.exception.status_code, 422)
        db.table.return_value.insert.assert_not_called()


if __name__ == "__main__":
    unittest.main()
