from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from app.auth import get_current_user
from app.services.supabase_client import supabase
from app.services.ai_service import generate_flashcards

router = APIRouter(prefix="/materials", tags=["Flashcards"])

@router.post("/{material_id}/flashcards/generate")
def create_flashcards(material_id: str, user = Depends(get_current_user)):
    """
    Mengenerate flashcard baru menggunakan AI berdasarkan ringkasan materi,
    lalu menyimpannya ke database.
    """
    # 1. Pastikan materi milik user
    mat_res = supabase.table("materials").select("id").eq("id", material_id).eq("user_id", user.id).execute()
    if not mat_res.data:
        raise HTTPException(status_code=404, detail="Materi tidak ditemukan")
        
    # 2. Ambil ringkasan dari database untuk dijadikan bahan pembuat flashcard
    sum_res = supabase.table("summaries").select("overview, sections").eq("material_id", material_id).execute()
    if not sum_res.data:
        raise HTTPException(status_code=400, detail="Ringkasan belum ada. Proses materi terlebih dahulu.")
        
    summary_data = sum_res.data[0]
    # Gabungkan teks untuk dibaca AI (Overview + judul-judul bagian)
    bahan_teks = summary_data["overview"] + "\n"
    for sec in summary_data["sections"]:
        bahan_teks += f"- {sec['title']}\n"
    
    # 3. Panggil Gemini AI (langsung ditunggu karena prosesnya cepat)
    try:
        flashcards_data = generate_flashcards(bahan_teks)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
        
    # 4. Hapus flashcard lama (jika ada) agar tidak dobel
    supabase.table("flashcards").delete().eq("material_id", material_id).execute()
    
    # 5. Simpan flashcard baru ke database
    for card in flashcards_data:
        card["material_id"] = material_id # Tambahkan ID materi ke setiap kartu
        
    if flashcards_data:
        supabase.table("flashcards").insert(flashcards_data).execute()
        
    return {"message": f"Berhasil membuat {len(flashcards_data)} flashcard.", "data": flashcards_data}


@router.get("/{material_id}/flashcards")
def get_flashcards(material_id: str, user = Depends(get_current_user)):
    """
    Mengambil semua flashcard untuk materi tertentu.
    """
    # Cek kepemilikan materi
    mat_res = supabase.table("materials").select("id").eq("id", material_id).eq("user_id", user.id).execute()
    if not mat_res.data:
        raise HTTPException(status_code=404, detail="Materi tidak ditemukan")
        
    # Ambil flashcards
    fc_res = supabase.table("flashcards").select("*").eq("material_id", material_id).execute()
    
    reviews = supabase.table("flashcard_reviews").select("flashcard_id").eq("user_id", user.id).eq("material_id", material_id).execute()
    reviewed_ids = {row["flashcard_id"] for row in reviews.data}
    return [dict(card, studied=card["id"] in reviewed_ids) for card in fc_res.data]


@router.post("/{material_id}/flashcards/{flashcard_id}/studied")
def mark_flashcard_studied(material_id: UUID, flashcard_id: UUID, user=Depends(get_current_user)):
    material_id, flashcard_id = str(material_id), str(flashcard_id)
    material = supabase.table("materials").select("id").eq("id", material_id).eq("user_id", user.id).execute()
    if not material.data:
        raise HTTPException(status_code=404, detail="Materi tidak ditemukan")
    card = supabase.table("flashcards").select("id").eq("id", flashcard_id).eq("material_id", material_id).execute()
    if not card.data:
        raise HTTPException(status_code=404, detail="Flashcard tidak ditemukan")
    supabase.table("flashcard_reviews").upsert(
        {"user_id": user.id, "flashcard_id": flashcard_id, "material_id": material_id},
        on_conflict="user_id,flashcard_id",
        ignore_duplicates=True,
    ).execute()
    return {"studied": True}


@router.get("/flashcards/reviews/count")
def get_flashcard_review_count(user=Depends(get_current_user)):
    result = supabase.table("flashcard_reviews").select("flashcard_id", count="exact", head=True).eq("user_id", user.id).execute()
    return {"count": result.count}