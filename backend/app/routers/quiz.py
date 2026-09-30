from fastapi import APIRouter, Depends, HTTPException
from app.auth import get_current_user
from app.services.supabase_client import supabase
from app.services.ai_service import generate_quiz_questions
from app.schemas.quiz import GenerateQuizRequest, SubmitQuizRequest

router = APIRouter(tags=["Quiz"])

# 1. Endpoint Generate Quiz
@router.post("/materials/{material_id}/quiz/generate")
def create_quiz(material_id: str, req: GenerateQuizRequest, user = Depends(get_current_user)):
    # Pastikan materi milik user
    mat_res = supabase.table("materials").select("id").eq("id", material_id).eq("user_id", user.id).execute()
    if not mat_res.data:
        raise HTTPException(status_code=404, detail="Materi tidak ditemukan")
        
    # Ambil ringkasan
    sum_res = supabase.table("summaries").select("overview, sections").eq("material_id", material_id).execute()
    if not sum_res.data:
        raise HTTPException(status_code=400, detail="Ringkasan belum ada.")
        
    summary_data = sum_res.data[0]
    bahan_teks = summary_data["overview"] + "\n"
    for sec in summary_data["sections"]:
        bahan_teks += f"- {sec['title']}\n"
    
    # Generate soal dengan AI
    try:
        questions_data = generate_quiz_questions(bahan_teks, req.amount, req.difficulty)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
        
    # Buat header kuis di tabel 'quizzes'
    quiz_title = f"Quiz {req.difficulty.capitalize()} - {req.amount} Soal"
    quiz_insert = supabase.table("quizzes").insert({
        "material_id": material_id,
        "title": quiz_title
    }).execute()
    quiz_id = quiz_insert.data[0]["id"]
    
    # Simpan soal-soal ke tabel 'quiz_questions'
    for q in questions_data:
        q["quiz_id"] = quiz_id
        
    supabase.table("quiz_questions").insert(questions_data).execute()
        
    return {"message": "Quiz berhasil dibuat", "quiz_id": quiz_id}

# 2. Endpoint Ambil Soal Kuis (tanpa kunci jawaban, agar Flutter tidak bisa menyontek)
@router.get("/quizzes/{quiz_id}")
def get_quiz_questions(quiz_id: str, user = Depends(get_current_user)):
    quiz_res = supabase.table("quizzes").select("*").eq("id", quiz_id).execute()
    if not quiz_res.data:
        raise HTTPException(status_code=404, detail="Quiz tidak ditemukan")
        
    # Ambil soal tapi JANGAN ambil correct_index dan explanation
    q_res = supabase.table("quiz_questions").select("id, question, options").eq("quiz_id", quiz_id).execute()
    
    return {
        "quiz": quiz_res.data[0],
        "questions": q_res.data
    }

# 3. Endpoint Submit Jawaban & Hitung Skor
@router.post("/quizzes/{quiz_id}/attempts")
def submit_quiz_attempt(quiz_id: str, req: SubmitQuizRequest, user = Depends(get_current_user)):
    # Ambil kunci jawaban dari database
    q_res = supabase.table("quiz_questions").select("id, correct_index, explanation").eq("quiz_id", quiz_id).execute()
    if not q_res.data:
        raise HTTPException(status_code=404, detail="Soal quiz tidak ditemukan")
        
    # Jadikan dictionary agar mudah dicek (question_id -> data)
    kunci_jawaban = {q["id"]: q for q in q_res.data}
    
    benar = 0
    total_soal = len(kunci_jawaban)
    detail_jawaban = []
    
    # Cek jawaban user satu per satu
    for ans in req.answers:
        kunci = kunci_jawaban.get(ans.question_id)
        if not kunci:
            continue
            
        is_correct = (ans.selected_index == kunci["correct_index"])
        if is_correct:
            benar += 1
            
        detail_jawaban.append({
            "question_id": ans.question_id,
            "selected_index": ans.selected_index,
            "is_correct": is_correct
        })
        
    # Hitung skor skala 100
    skor = int((benar / total_soal) * 100) if total_soal > 0 else 0
    
    # Simpan attempt ke database
    attempt_insert = supabase.table("quiz_attempts").insert({
        "quiz_id": quiz_id,
        "user_id": user.id,
        "score": skor
    }).execute()
    attempt_id = attempt_insert.data[0]["id"]
    
    # Simpan detail jawaban
    for detail in detail_jawaban:
        detail["attempt_id"] = attempt_id
    supabase.table("quiz_answers").insert(detail_jawaban).execute()
    
    return {
        "message": "Quiz selesai!",
        "score": skor,
        "benar": benar,
        "total": total_soal,
        "attempt_id": attempt_id
    }