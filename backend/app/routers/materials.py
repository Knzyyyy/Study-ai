import os
import tempfile
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from app.auth import get_current_user
from app.services.supabase_client import supabase
from app.services.extractor import extract_text_from_pdf, extract_text_from_pptx
from app.services.summarizer import process_material_text
from app.services.ai_service import MODEL, generate_flashcards, generate_quiz_questions
from pydantic import BaseModel, ConfigDict, StrictBool


class ProcessMaterialRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    generate_summary: StrictBool = True
    generate_flashcards: StrictBool = False
    generate_quiz: StrictBool = False

router = APIRouter(prefix="/materials", tags=["Materials"])

def process_material_background(material_id: str, user_id: str, options: ProcessMaterialRequest | None = None):
    options = options or ProcessMaterialRequest()
    """
    Fungsi ini berjalan di background (tidak memblokir respon API).
    Tugasnya: Download file -> Ekstrak -> Ringkas -> Simpan ke DB.
    """
    try:
        # 1. Ambil data materi dari tabel 'materials'
        res = supabase.table("materials").select("*").eq("id", material_id).eq("user_id", user_id).execute()
        if not res.data:
            print(f"Materi {material_id} tidak ditemukan atau bukan milik user {user_id}")
            return
            
        material = res.data[0]
        file_path_in_storage = material["file_path"]
        file_type = material["file_type"]

        if material["status"] != "processing":
            return

        # 2. Download file dari Supabase Storage (Bucket harus bernama 'materials')
        file_data = supabase.storage.from_("materials").download(file_path_in_storage)
        
        # Simpan file sementara ke lokal backend untuk dibaca PyMuPDF/pptx
        suffix = f".{file_type}" 
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp_file:
            tmp_file.write(file_data)
            local_file_path = tmp_file.name

        # 3. Ekstrak Teks
        print(f"Mengekstrak teks dari {local_file_path}...")
        if file_type == "pdf":
            pages = extract_text_from_pdf(local_file_path)
        else:
            pages = extract_text_from_pptx(local_file_path)
            
        # Hapus file lokal sementara karena sudah tidak dipakai
        os.remove(local_file_path)

        # 4. Simpan teks tiap halaman ke tabel 'material_pages'
        pages_data = [{
            "material_id": material_id, 
            "page_number": p["page_number"], 
            "content_text": p["content_text"]
        } for p in pages]
        
        existing_pages = supabase.table("material_pages").select("page_number").eq("material_id", material_id).execute().data
        page_numbers = {page["page_number"] for page in existing_pages}
        missing_pages = [page for page in pages_data if page["page_number"] not in page_numbers]
        if missing_pages:
            supabase.table("material_pages").insert(missing_pages).execute()

        if options.generate_summary and not supabase.table("summaries").select("id").eq("material_id", material_id).execute().data:
            summary_result = process_material_text(pages)
            supabase.table("summaries").insert({
                "material_id": material_id,
                "overview": summary_result["overview"],
                "sections": summary_result["sections"],
                "key_terms": summary_result["key_terms"],
                "model_used": MODEL,
            }).execute()

        source_text = "\n\n".join(p["content_text"] for p in pages)
        if options.generate_flashcards and not supabase.table("flashcards").select("id").eq("material_id", material_id).execute().data:
            cards = generate_flashcards(source_text)
            if cards:
                supabase.table("flashcards").insert([
                    {**card, "material_id": material_id} for card in cards
                ]).execute()

        existing_quizzes = supabase.table("quizzes").select("id").eq("material_id", material_id).execute().data if options.generate_quiz else []
        complete_quiz = any(supabase.table("quiz_questions").select("id").eq("quiz_id", quiz["id"]).execute().data for quiz in existing_quizzes)
        if options.generate_quiz and not complete_quiz:
            questions = generate_quiz_questions(source_text, 10, "medium")
            if not questions:
                raise ValueError("AI tidak menghasilkan soal kuis")
            if existing_quizzes:
                quiz_id = existing_quizzes[0]["id"]
            else:
                quiz = supabase.table("quizzes").insert({
                    "material_id": material_id,
                    "title": "Quiz Medium - 10 Soal",
                }).execute()
                quiz_id = quiz.data[0]["id"]
            supabase.table("quiz_questions").insert([
                {**question, "quiz_id": quiz_id} for question in questions
            ]).execute()

        # 7. Update status materi menjadi 'done'
        supabase.table("materials").update({
            "status": "done",
            "page_count": len(pages),
            "error_message": None
        }).eq("id", material_id).eq("user_id", user_id).eq("status", "processing").execute()
        
        print(f"Selesai memproses materi: {material_id}")

    except Exception as e:
        # Jika gagal di tengah jalan, update status jadi 'failed'
        print(f"Gagal memproses {material_id}: {str(e)}")
        supabase.table("materials").update({
            "status": "failed",
            "error_message": str(e)
        }).eq("id", material_id).eq("user_id", user_id).eq("status", "processing").execute()


# Endpoint untuk Flutter memicu proses (Harus pakai Token JWT)
@router.post("/{material_id}/process")
def trigger_process_material(material_id: str, background_tasks: BackgroundTasks, req: ProcessMaterialRequest | None = None, user = Depends(get_current_user)):
    rows = supabase.table("materials").select("status").eq("id", material_id).eq("user_id", user.id).execute().data
    if not rows:
        raise HTTPException(status_code=404, detail="Materi tidak ditemukan")
    status = rows[0]["status"]
    if status in ("processing", "done"):
        return {"material_id": material_id, "status": status}
    if status not in ("uploaded", "failed"):
        raise HTTPException(status_code=409, detail="Status materi tidak dapat diproses")
    claimed = supabase.table("materials").update({"status": "processing", "error_message": None}).eq("id", material_id).eq("user_id", user.id).eq("status", status).execute().data
    if claimed:
        background_tasks.add_task(process_material_background, material_id, user.id, req or ProcessMaterialRequest())
    return {"material_id": material_id, "status": "processing"}

# Endpoint tambahan: Cek Status
@router.get("/{material_id}/status")
def get_material_status(material_id: str, user = Depends(get_current_user)):
    res = supabase.table("materials").select("status, error_message").eq("id", material_id).eq("user_id", user.id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Materi tidak ditemukan")
    return res.data[0]

# ==========================================
# ENDPOINT UNTUK MEMBACA & REGENERATE SUMMARY
# ==========================================

@router.get("/{material_id}/summary")
def get_material_summary(material_id: str, user = Depends(get_current_user)):
    """
    Mengambil hasil ringkasan dari database.
    Hanya bisa diakses jika materi ini milik user yang sedang login.
    """
    # 1. Pastikan materi ini milik user tersebut
    mat_res = supabase.table("materials").select("id").eq("id", material_id).eq("user_id", user.id).execute()
    if not mat_res.data:
        raise HTTPException(status_code=404, detail="Materi tidak ditemukan atau akses ditolak")

    # 2. Ambil ringkasan dari tabel summaries
    sum_res = supabase.table("summaries").select("*").eq("material_id", material_id).execute()
    if not sum_res.data:
        raise HTTPException(status_code=404, detail="Ringkasan belum tersedia (mungkin masih diproses)")

    # 3. Kembalikan data ringkasan ke Flutter
    return sum_res.data[0]


@router.post("/{material_id}/summary/regenerate")
def regenerate_summary(material_id: str, background_tasks: BackgroundTasks, user = Depends(get_current_user)):
    """
    Meminta AI mengulang proses ringkasan (hanya ringkasan, tidak perlu ekstrak PDF lagi dari nol).
    """
    # 1. Pastikan materi valid
    mat_res = supabase.table("materials").select("id, status").eq("id", material_id).eq("user_id", user.id).execute()
    if not mat_res.data:
        raise HTTPException(status_code=404, detail="Materi tidak ditemukan")
        
    status = mat_res.data[0]["status"]
    if status == "processing":
        return {"status": status}
    claimed = supabase.table("materials").update({"status": "processing", "error_message": None}).eq("id", material_id).eq("user_id", user.id).eq("status", status).execute().data
    if claimed:
        background_tasks.add_task(regenerate_summary_background, material_id, user.id)
    return {"status": "processing"}


def regenerate_summary_background(material_id: str, user_id: str):
    try:
        pages = supabase.table("material_pages").select("page_number, content_text").eq("material_id", material_id).order("page_number").execute().data
        if not pages:
            raise ValueError("Teks materi belum tersedia")
        result = process_material_text(pages)
        payload = {"material_id": material_id, **result, "model_used": MODEL}
        existing = supabase.table("summaries").select("id").eq("material_id", material_id).execute().data
        if existing:
            supabase.table("summaries").update(payload).eq("id", existing[0]["id"]).execute()
        else:
            supabase.table("summaries").insert(payload).execute()
        supabase.table("materials").update({"status": "done", "error_message": None}).eq("id", material_id).eq("user_id", user_id).eq("status", "processing").execute()
    except Exception as error:
        supabase.table("materials").update({"status": "failed", "error_message": str(error)}).eq("id", material_id).eq("user_id", user_id).eq("status", "processing").execute()