import json
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from app.auth import get_current_user
from app.services.supabase_client import supabase
from app.services.ai_service import get_chat_stream
from app.schemas.chat import CreateSessionRequest, SendMessageRequest

router = APIRouter(prefix="/chat", tags=["AI Tutor Chat"])

# 1. Membuat sesi chat baru
@router.post("/sessions")
def create_chat_session(req: CreateSessionRequest, user = Depends(get_current_user)):
    # Pastikan materi ada dan milik user
    mat_res = supabase.table("materials").select("id").eq("id", req.material_id).eq("user_id", user.id).execute()
    if not mat_res.data:
        raise HTTPException(status_code=404, detail="Materi tidak ditemukan")
        
    res = supabase.table("chat_sessions").insert({
        "material_id": req.material_id,
        "user_id": user.id
    }).execute()
    
    return res.data[0]

# 2. Mengambil riwayat chat
@router.get("/sessions/{session_id}/messages")
def get_chat_messages(session_id: str, user = Depends(get_current_user)):
    # Validasi kepemilikan
    sess_res = supabase.table("chat_sessions").select("id").eq("id", session_id).eq("user_id", user.id).execute()
    if not sess_res.data:
        raise HTTPException(status_code=404, detail="Sesi tidak valid")
        
    # Ambil pesan, urutkan dari yang paling lama ke baru (created_at ascending)
    msg_res = supabase.table("chat_messages").select("*").eq("session_id", session_id).order("created_at").execute()
    return msg_res.data

# 3. Mengirim pesan dan menerima respons Streaming (SSE)
@router.post("/sessions/{session_id}/messages")
def send_message_stream(session_id: str, req: SendMessageRequest, user = Depends(get_current_user)):
    # 1. Validasi Sesi dan Ambil Konteks Materi
    sess_res = supabase.table("chat_sessions").select("material_id").eq("id", session_id).eq("user_id", user.id).execute()
    if not sess_res.data:
        raise HTTPException(status_code=404, detail="Sesi tidak valid")
        
    material_id = sess_res.data[0]["material_id"]
    
    # Ambil ringkasan (dan mungkin teks aslinya jika dibutuhkan nanti) untuk konteks AI
    sum_res = supabase.table("summaries").select("overview, sections").eq("material_id", material_id).execute()
    context_text = ""
    if sum_res.data:
        context_text = sum_res.data[0]["overview"] + "\n\n"
        for sec in sum_res.data[0]["sections"]:
            context_text += f"- {sec['title']}: {', '.join(sec['key_points'])}\n"
            
    # 2. Simpan pesan USER ke database
    supabase.table("chat_messages").insert({
        "session_id": session_id,
        "role": "user",
        "content": req.content
    }).execute()
    
    # 3. Ambil riwayat chat sebelumnya (maksimal 10 terakhir agar konteks tidak kepenuhan)
    history_res = supabase.table("chat_messages").select("role, content").eq("session_id", session_id).order("created_at", desc=True).limit(10).execute()
    
    # Karena kita ambil desc (terbaru di atas), kita harus membaliknya agar urut waktu
    chat_history = list(reversed(history_res.data))
    
    # Keluarkan pesan user yang baru di-insert agar tidak dobel di prompt
    chat_history.pop() 

    # 4. Fungsi Generator untuk SSE
    def event_generator():
        full_ai_response = ""
        try:
            stream = get_chat_stream(context_text, chat_history, req.content)
            for chunk in stream:
                text = chunk.text
                if text:
                    full_ai_response += text
                    # Kita ubah ke JSON agar karakter spesial (seperti \n atau kutip) tidak merusak format SSE
                    payload = json.dumps({"text": text})
                    yield f"data: {payload}\n\n"
                    
            # Kirim sinyal bahwa AI sudah selesai bicara
            yield "data: [DONE]\n\n"
            
        except Exception as e:
            yield f"data: {json.dumps({'error': str(e)})}\n\n"
            
        finally:
            # 5. SETELAH stream selesai, simpan pesan lengkap AI ke database
            if full_ai_response.strip():
                supabase.table("chat_messages").insert({
                    "session_id": session_id,
                    "role": "assistant",
                    "content": full_ai_response
                }).execute()

    # Kembalikan response tipe SSE (text/event-stream)
    return StreamingResponse(event_generator(), media_type="text/event-stream")