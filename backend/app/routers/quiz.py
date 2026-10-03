from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException
from app.auth import get_current_user
from app.services.supabase_client import supabase
from app.services.ai_service import generate_quiz_questions
from app.schemas.quiz import GenerateQuizRequest, SubmitQuizRequest, QuizData

router = APIRouter(tags=["Quiz"])


def owned_material(material_id, user):
    rows = supabase.table("materials").select("id").eq("id", material_id).eq("user_id", user.id).execute().data
    if not rows:
        raise HTTPException(404, "Materi tidak ditemukan")


def owned_quiz(quiz_id, user):
    rows = supabase.table("quizzes").select("id, material_id, title").eq("id", quiz_id).execute().data
    if not rows:
        raise HTTPException(404, "Quiz tidak ditemukan")
    owned_material(rows[0]["material_id"], user)
    return rows[0]


@router.post("/materials/{material_id}/quiz/generate")
def create_quiz(material_id: str, req: GenerateQuizRequest, user=Depends(get_current_user)):
    owned_material(material_id, user)
    summaries = supabase.table("summaries").select("overview, sections").eq("material_id", material_id).execute().data
    text = ""
    if summaries:
        summary = summaries[0]
        text = (summary.get("overview") or "") + "\n" + "\n".join(sec.get("title", "") for sec in (summary.get("sections") or []))
    if not text.strip():
        pages = supabase.table("material_pages").select("content_text").eq("material_id", material_id).order("page_number").execute().data
        text = "\n\n".join(page.get("content_text") or "" for page in pages)
    if not text.strip():
        raise HTTPException(400, "Teks materi belum tersedia. Unggah materi dengan teks yang dapat diekstrak.")
    try:
        questions = QuizData(questions=generate_quiz_questions(text, req.amount, req.difficulty)).model_dump()["questions"]
        if len(questions) != req.amount:
            raise ValueError("Jumlah soal tidak sesuai permintaan")
    except Exception:
        raise HTTPException(502, "Gagal membuat soal valid. Silakan coba lagi.")
    quiz = supabase.table("quizzes").insert({"material_id": material_id, "title": f"Quiz {req.difficulty.capitalize()} - {req.amount} Soal"}).execute().data[0]
    try:
        supabase.table("quiz_questions").insert([{**q, "quiz_id": quiz["id"]} for q in questions]).execute()
    except Exception:
        supabase.table("quizzes").delete().eq("id", quiz["id"]).execute()
        raise HTTPException(500, "Gagal menyimpan soal")
    return {"message": "Quiz berhasil dibuat", "quiz_id": quiz["id"]}


@router.get("/materials/{material_id}/quiz")
def find_material_quiz(material_id: str, user=Depends(get_current_user)):
    owned_material(material_id, user)
    quizzes = supabase.table("quizzes").select("id, material_id, title").eq("material_id", material_id).order("id", desc=True).execute().data
    for quiz in quizzes:
        questions = supabase.table("quiz_questions").select("id, question, options").eq("quiz_id", quiz["id"]).order("id").execute().data
        if questions:
            return {"quiz": quiz, "questions": questions}
    return {"quiz": None, "questions": []}


@router.get("/quizzes/{quiz_id}")
def get_quiz_questions(quiz_id: str, user=Depends(get_current_user)):
    quiz = owned_quiz(quiz_id, user)
    questions = supabase.table("quiz_questions").select("id, question, options").eq("quiz_id", quiz_id).order("id").execute().data
    return {"quiz": quiz, "questions": questions}


def progress_for_attempts(attempts):
    scores = [a["score"] for a in attempts]
    dated = []
    for attempt in attempts:
        try:
            date = datetime.fromisoformat(attempt.get("created_at") or "")
            dated.append((date.replace(tzinfo=date.tzinfo or timezone.utc), attempt))
        except (ValueError, TypeError):
            pass
    last = max((date for date, _ in dated), default=None)
    latest = [a["score"] for date, a in dated if date == last]
    return {
        "count": len(scores),
        "mean_score": sum(scores) / len(scores) if scores else None,
        "best_score": max(scores) if scores else None,
        "latest_score": latest[0] if len(dated) == len(attempts) and len(latest) == 1 else None,
        "last_practiced_at": last.isoformat() if last else None,
    }


def all_rows(query):
    rows = []
    while True:
        page = query.range(len(rows), len(rows) + 499).execute().data
        rows.extend(page)
        if len(page) < 500:
            return rows


def material_progress(user, material_id=None):
    query = supabase.table("materials").select("id").eq("user_id", user.id)
    if material_id is not None:
        query = query.eq("id", material_id)
    materials = all_rows(query.order("id"))
    if material_id is not None and not materials:
        raise HTTPException(404, "Materi tidak ditemukan")
    grouped = {m["id"]: [] for m in materials}
    ids = list(grouped)
    for offset in range(0, len(ids), 100):
        quizzes = all_rows(supabase.table("quizzes").select("id, material_id").in_("material_id", ids[offset:offset + 100]).order("id"))
        mapping = {q["id"]: q["material_id"] for q in quizzes}
        quiz_ids = list(mapping)
        for start in range(0, len(quiz_ids), 100):
            attempts = all_rows(supabase.table("quiz_attempts").select("id, quiz_id, score, created_at").eq("user_id", user.id).in_("quiz_id", quiz_ids[start:start + 100]).order("id"))
            for attempt in attempts:
                grouped[mapping[attempt["quiz_id"]]].append(attempt)
    return {mid: progress_for_attempts(attempts) for mid, attempts in grouped.items()}


@router.get("/quiz-progress")
def list_material_progress(user=Depends(get_current_user)):
    return {"progress": material_progress(user)}


@router.get("/materials/{material_id}/quiz/progress")
def get_material_progress(material_id: str, user=Depends(get_current_user)):
    return material_progress(user, material_id)[material_id]


@router.get("/materials/{material_id}/quiz/attempts")
def list_quiz_attempts(material_id: str, user=Depends(get_current_user)):
    owned_material(material_id, user)
    quizzes = supabase.table("quizzes").select("id, title").eq("material_id", material_id).execute().data
    if not quizzes:
        return {"attempts": []}
    titles = {q["id"]: q["title"] for q in quizzes}
    attempts = supabase.table("quiz_attempts").select("id, quiz_id, score, created_at").in_("quiz_id", list(titles)).eq("user_id", user.id).order("created_at", desc=True).execute().data
    return {"attempts": [{**a, "title": titles[a["quiz_id"]]} for a in attempts]}


@router.get("/quiz-attempts/{attempt_id}")
def get_attempt_review(attempt_id: str, user=Depends(get_current_user)):
    rows = supabase.table("quiz_attempts").select("id, quiz_id, score, created_at").eq("id", attempt_id).eq("user_id", user.id).execute().data
    if not rows:
        raise HTTPException(404, "Percobaan tidak ditemukan")
    attempt = rows[0]
    quiz = owned_quiz(attempt["quiz_id"], user)
    questions = supabase.table("quiz_questions").select("id, question, options, correct_index, explanation").eq("quiz_id", quiz["id"]).order("id").execute().data
    answers = supabase.table("quiz_answers").select("question_id, selected_index").eq("attempt_id", attempt_id).execute().data
    selected = {a["question_id"]: a["selected_index"] for a in answers}
    review = [{**q, "selected_index": selected.get(q["id"])} for q in questions]
    return {"attempt": {**attempt, "title": quiz["title"]}, "questions": review}


@router.post("/quizzes/{quiz_id}/attempts")
def submit_quiz_attempt(quiz_id: str, req: SubmitQuizRequest, user=Depends(get_current_user)):
    owned_quiz(quiz_id, user)
    questions = supabase.table("quiz_questions").select("id, options, correct_index").eq("quiz_id", quiz_id).execute().data
    if not questions:
        raise HTTPException(404, "Soal quiz tidak ditemukan")
    keys = {q["id"]: q for q in questions}
    selected = {a.question_id: a.selected_index for a in req.answers}
    if len(selected) != len(req.answers) or set(selected) != set(keys):
        raise HTTPException(422, "Jawab semua soal tepat satu kali")
    if any(index < 0 or index >= len(keys[qid]["options"]) for qid, index in selected.items()):
        raise HTTPException(422, "Pilihan jawaban tidak valid")
    details = [{"question_id": qid, "selected_index": index, "is_correct": index == keys[qid]["correct_index"]} for qid, index in selected.items()]
    correct = sum(d["is_correct"] for d in details)
    score = int(correct / len(keys) * 100)
    attempt = supabase.table("quiz_attempts").insert({"quiz_id": quiz_id, "user_id": user.id, "score": score}).execute().data[0]
    try:
        supabase.table("quiz_answers").insert([{**d, "attempt_id": attempt["id"]} for d in details]).execute()
    except Exception:
        supabase.table("quiz_attempts").delete().eq("id", attempt["id"]).eq("user_id", user.id).execute()
        raise HTTPException(500, "Gagal menyimpan jawaban. Silakan coba lagi.")
    return {"message": "Quiz selesai!", "score": score, "benar": correct, "total": len(keys), "attempt_id": attempt["id"]}
