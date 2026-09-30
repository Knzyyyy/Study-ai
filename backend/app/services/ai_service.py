import os
import time
from google import genai
from pydantic import ValidationError
from app.schemas.summary import SectionSummary, OverviewResponse
from app.schemas.flashcard import FlashcardList
from app.schemas.quiz import QuizData

def summarize_section(text_chunk: str, max_retries: int = 2) -> SectionSummary:
    """
    Mengirim 1 chunk teks ke Gemini untuk diringkas.
    Akan mencoba ulang (retry) jika server sibuk atau JSON rusak.
    """
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise ValueError("GEMINI_API_KEY belum di-set di file .env")

    client = genai.Client(api_key=api_key)
    
    prompt = f"""
    Kamu adalah asisten dosen yang ahli dalam meringkas materi kuliah.
    Analisis teks materi berikut dan buat ringkasan terstruktur.
    
    Materi:
    {text_chunk}
    """
    
    for attempt in range(max_retries + 1):
        try:
            response = client.models.generate_content(
                model='gemini-3.8-flash',
                contents=prompt,
                config=genai.types.GenerateContentConfig(
                    response_mime_type="application/json",
                    response_schema=SectionSummary,
                    temperature=0.3,
                ),
            )
            return SectionSummary.model_validate_json(response.text)
            
        except Exception as e:
            if attempt < max_retries:
                print(f"[AI Service] Gagal (Error 503/JSON rusak). Mencoba lagi dalam 3 detik... (Percobaan ke-{attempt+2})")
                time.sleep(3)  # Jeda 3 detik sebelum mencoba lagi
            else:
                raise Exception(f"Gagal memanggil Gemini API setelah {max_retries} kali retry: {e}")

def generate_overview(sections: list[SectionSummary], max_retries: int = 2) -> str:
    """
    Membaca semua ringkasan per bagian, lalu meminta AI membuat 1 paragraf overview singkat.
    """
    api_key = os.getenv("GEMINI_API_KEY")
    client = genai.Client(api_key=api_key)
    
    combined_text = ""
    for idx, sec in enumerate(sections):
        combined_text += f"\nBagian {idx+1}: {sec.title}\n"
        combined_text += "Poin: " + ", ".join(sec.key_points) + "\n"
        
    prompt = f"""
    Kamu adalah dosen yang membuat ringkasan singkat.
    Berdasarkan poin-poin materi kuliah di bawah ini, buatlah SATU paragraf ringkasan keseluruhan (overview) 
    yang menjelaskan apa inti dari materi ini (maksimal 3-4 kalimat).
    
    Materi:
    {combined_text}
    """
    
    for attempt in range(max_retries + 1):
        try:
            response = client.models.generate_content(
                model='gemini-3.8-flash',
                contents=prompt,
                config=genai.types.GenerateContentConfig(
                    response_mime_type="application/json",
                    response_schema=OverviewResponse,
                    temperature=0.4,
                ),
            )
            overview_obj = OverviewResponse.model_validate_json(response.text)
            return overview_obj.overview
        except Exception as e:
            if attempt < max_retries:
                print(f"[AI Service] Gagal membuat overview. Mencoba lagi dalam 3 detik... (Percobaan ke-{attempt+2})")
                time.sleep(3)
            else:
                raise Exception(f"Gagal membuat overview setelah {max_retries} kali retry: {e}")

def generate_flashcards(summary_text: str, max_retries: int = 2) -> list[dict]:
    """
    Meminta Gemini membuat kumpulan flashcard berdasarkan teks ringkasan materi.
    """
    api_key = os.getenv("GEMINI_API_KEY")
    client = genai.Client(api_key=api_key)
    
    prompt = f"""
    Kamu adalah AI Tutor. Buatlah maksimal 10 flashcard (kartu belajar) berdasarkan materi berikut.
    Sisi depan (front) berisi pertanyaan singkat atau istilah.
    Sisi belakang (back) berisi jawaban atau definisi singkat.
    
    Materi:
    {summary_text}
    """
    
    for attempt in range(max_retries + 1):
        try:
            response = client.models.generate_content(
                model='gemini-3.8-flash',
                contents=prompt,
                config=genai.types.GenerateContentConfig(
                    response_mime_type="application/json",
                    response_schema=FlashcardList,
                    temperature=0.4,
                ),
            )
            flashcards_obj = FlashcardList.model_validate_json(response.text)
            # Ubah object Pydantic menjadi list of dictionary agar mudah masuk ke Supabase
            return [card.model_dump() for card in flashcards_obj.flashcards]
            
        except Exception as e:
            if attempt < max_retries:
                print(f"[AI Service] Gagal membuat flashcard. Mencoba lagi... (Percobaan ke-{attempt+2})")
                time.sleep(3)
            else:
                raise Exception(f"Gagal membuat flashcard setelah {max_retries} kali retry: {e}")

def generate_quiz_questions(summary_text: str, amount: int, difficulty: str, max_retries: int = 2) -> list[dict]:
    """
    Meminta Gemini membuat soal pilihan ganda (4 opsi).
    """
    api_key = os.getenv("GEMINI_API_KEY")
    client = genai.Client(api_key=api_key)
    
    prompt = f"""
    Kamu adalah dosen penguji. Buatlah {amount} soal pilihan ganda tingkat kesulitan "{difficulty}" berdasarkan materi berikut.
    Setiap soal harus memiliki tepat 4 opsi jawaban.
    Berikan juga index jawaban yang benar (0 untuk opsi pertama, 1 untuk kedua, dst) dan penjelasan singkat.
    
    Materi:
    {summary_text}
    """
    
    for attempt in range(max_retries + 1):
        try:
            response = client.models.generate_content(
                model='gemini-3.8-flash',
                contents=prompt,
                config=genai.types.GenerateContentConfig(
                    response_mime_type="application/json",
                    response_schema=QuizData,
                    temperature=0.4,
                ),
            )
            quiz_obj = QuizData.model_validate_json(response.text)
            return [q.model_dump() for q in quiz_obj.questions]
            
        except Exception as e:
            if attempt < max_retries:
                print(f"[AI Service] Gagal membuat quiz. Mencoba lagi... (Percobaan ke-{attempt+2})")
                time.sleep(3)
            else:
                raise Exception(f"Gagal membuat quiz: {e}")

def get_chat_stream(context_text: str, chat_history: list[dict], new_message: str):
    """
    Fungsi ini memanggil Gemini menggunakan mode 'stream' (mengembalikan data sepotong-sepotong).
    Menerima konteks materi dan riwayat chat sebelumnya agar AI tidak 'lupa' obrolan.
    """
    api_key = os.getenv("GEMINI_API_KEY")
    client = genai.Client(api_key=api_key)
    
    # Format riwayat chat untuk Gemini (role 'user' dan 'model')
    contents = []
    for msg in chat_history:
        role = "model" if msg["role"] == "assistant" else "user"
        contents.append({"role": role, "parts": [{"text": msg["content"]}]})
        
    # Tambahkan pesan baru dari user
    contents.append({"role": "user", "parts": [{"text": new_message}]})

    # Instruksi sistem (System Prompt) yang dibekali dengan konteks materi
    system_instruction = f"""
    Kamu adalah AI Tutor yang ramah dan suportif untuk mahasiswa.
    Gunakan gaya bahasa santai tapi sopan (Bahasa Indonesia).
    Jawablah pertanyaan berdasarkan materi kuliah berikut ini. Jika pertanyaan di luar konteks materi, 
    arahkan kembali ke materi secara sopan.
    
    Konteks Materi:
    {context_text}
    """
    
    # Mengembalikan generator stream dari Gemini
    response = client.models.generate_content_stream(
        model='gemini-3.8-flash',
        contents=contents,
        config=genai.types.GenerateContentConfig(
            system_instruction=system_instruction,
            temperature=0.5, # Sedikit lebih kreatif untuk chat, tapi tetap fokus
        )
    )
    
    return response