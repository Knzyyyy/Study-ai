import os
import tempfile
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from app.auth import get_current_user
from app.services.supabase_client import supabase
from app.services.extractor import extract_text_from_pdf, extract_text_from_pptx
from app.services.summarizer import process_material_text

router = APIRouter(prefix="/materials", tags=["Materials"])

def process_material_background(material_id: str, user_id: str):
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

        # Ubah status jadi 'processing'
        supabase.table("materials").update({"status": "processing"}).eq("id", material_id).execute()

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
        
        if pages_data:
            supabase.table("material_pages").insert(pages_data).execute()

        # 5. Jalankan AI Summarizer (Proses Map-Reduce)
        print("Memulai proses ringkasan AI...")
        summary_result = process_material_text(pages)

        # 6. Simpan hasil ringkasan ke tabel 'summaries'
        supabase.table("summaries").insert({
            "material_id": material_id,
            "overview": summary_result["overview"],
            "sections": summary_result["sections"], # jsonb format
            "key_terms": summary_result["key_terms"], # jsonb format
            "model_used": "gemini-3.8-flash"
        }).execute()

        # 7. Update status materi menjadi 'done'
        supabase.table("materials").update({
            "status": "done",
            "page_count": len(pages),
            "error_message": None
        }).eq("id", material_id).execute()
        
        print(f"✅ Selesai memproses materi: {material_id}")

    except Exception as e:
        # Jika gagal di tengah jalan, update status jadi 'failed'
        print(f"❌ Gagal memproses {material_id}: {str(e)}")
        supabase.table("materials").update({
            "status": "failed",
            "error_message": str(e)
        }).eq("id", material_id).execute()


# Endpoint untuk Flutter memicu proses (Harus pakai Token JWT)
@router.post("/{material_id}/process")
def trigger_process_material(material_id: str, background_tasks: BackgroundTasks, user = Depends(get_current_user)):
    # FastAPI akan langsung mengembalikan respon, sementara fungsi background jalan terus
    background_tasks.add_task(process_material_background, material_id, user.id)
    
    return {
        "message": "Proses ekstraksi dan ringkasan sedang berjalan di background",
        "material_id": material_id
    }

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
        
    # 2. Hapus ringkasan yang lama (jika ada)
    supabase.table("summaries").delete().eq("material_id", material_id).execute()
    
    # 3. Kembalikan status materi menjadi 'processing'
    supabase.table("materials").update({"status": "processing"}).eq("id", material_id).execute()
    
    # 4. Panggil ulang background task
    # (Perhatikan: di aplikasi sungguhan, kita bisa bikin fungsi khusus agar tidak ekstrak PDF lagi, 
    # tapi untuk MVP, kita panggil fungsi yang sama agar kodenya sederhana dan bersih).
    background_tasks.add_task(process_material_background, material_id, user.id)
    
    return {"message": "Permintaan generate ulang diterima. Proses sedang berjalan di background."}