import json
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from app.auth import get_current_user
from app.services.supabase_client import supabase
from app.services.ai_service import get_chat_stream
from app.schemas.chat import CreateSessionRequest, SendMessageRequest

router = APIRouter(prefix="/chat", tags=["AI Tutor Chat"])


def owned_material(material_id, user):
    res = supabase.table("materials").select("id").eq("id", material_id).eq("user_id", user.id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Materi tidak ditemukan")


def owned_session(session_id, user):
    res = supabase.table("chat_sessions").select("material_id").eq("id", session_id).eq("user_id", user.id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Sesi tidak valid")
    material_id = res.data[0]["material_id"]
    owned_material(material_id, user)
    return material_id


@router.post("/sessions")
def create_chat_session(req: CreateSessionRequest, user=Depends(get_current_user)):
    owned_material(req.material_id, user)
    res = supabase.table("chat_sessions").insert({"material_id": req.material_id, "user_id": user.id}).execute()
    return res.data[0]


@router.get("/sessions")
def list_chat_sessions(material_id: str, user=Depends(get_current_user)):
    owned_material(material_id, user)
    sessions = supabase.table("chat_sessions").select("id").eq("material_id", material_id).eq("user_id", user.id).execute().data
    result = []
    for session in sessions:
        messages = supabase.table("chat_messages").select("role, content, created_at").eq("session_id", session["id"]).order("created_at").execute().data
        title = next((m["content"].strip()[:80] for m in messages if m["role"] == "user" and m["content"].strip()), "Chat Baru")
        dates = [m["created_at"] for m in messages if m.get("created_at")]
        result.append({"id": session["id"], "title": title, "last_message_at": max(dates, key=lambda d: datetime.fromisoformat(d.replace("Z", "+00:00")).timestamp()) if dates else None})
    result.sort(key=lambda s: datetime.fromisoformat(s["last_message_at"].replace("Z", "+00:00")).timestamp() if s["last_message_at"] else float("-inf"), reverse=True)
    return result


@router.get("/sessions/{session_id}/messages")
def get_chat_messages(session_id: str, user=Depends(get_current_user)):
    owned_session(session_id, user)
    return supabase.table("chat_messages").select("*").eq("session_id", session_id).order("created_at").execute().data


@router.post("/sessions/{session_id}/messages")
def send_message_stream(session_id: str, req: SendMessageRequest, user=Depends(get_current_user)):
    material_id = owned_session(session_id, user)
    sum_res = supabase.table("summaries").select("overview, sections").eq("material_id", material_id).execute()
    context_text = ""
    if sum_res.data:
        context_text = sum_res.data[0]["overview"] + "\n\n"
        for sec in sum_res.data[0]["sections"]:
            context_text += f"- {sec['title']}: {', '.join(sec['key_points'])}\n"
    history = supabase.table("chat_messages").select("role, content").eq("session_id", session_id).order("created_at", desc=True).limit(10).execute().data
    supabase.table("chat_messages").insert({"session_id": session_id, "role": "user", "content": req.content}).execute()

    def event_generator():
        full_response = ""
        error = None
        try:
            for text in get_chat_stream(context_text, list(reversed(history)), req.content):
                if text:
                    full_response += text
                    yield f"data: {json.dumps({'text': text})}\n\n"
        except Exception:
            error = "Respons AI terputus. Muat ulang riwayat sebelum mencoba lagi."
        finally:
            if full_response.strip():
                try:
                    owned_session(session_id, user)
                    supabase.table("chat_messages").insert({"session_id": session_id, "role": "assistant", "content": full_response}).execute()
                except Exception:
                    error = "Respons gagal disimpan. Salin respons sebelum memuat ulang."
        if error:
            yield f"data: {json.dumps({'error': error})}\n\n"
        else:
            yield "data: [DONE]\n\n"

    return StreamingResponse(event_generator(), media_type="text/event-stream")
