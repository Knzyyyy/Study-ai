import json
import os
import time
from collections.abc import Iterator

from openai import OpenAI

from app.schemas.flashcard import FlashcardList
from app.schemas.quiz import QuizData
from app.schemas.summary import OverviewResponse, SectionSummary
from app.config import settings

MODEL = settings.OPENAI_MODEL


def _client() -> OpenAI:
    api_key = settings.OPENAI_API_KEY
    if not api_key or api_key == "ISI_OPENAI_API_KEY_DI_SINI":
        raise ValueError("OPENAI_API_KEY belum di-set di file .env")
    return OpenAI(api_key=api_key, base_url=settings.OPENAI_BASE_URL)


def _strict_schema(schema: type) -> dict:
    result = schema.model_json_schema()

    def fix_objects(value):
        if isinstance(value, dict):
            if value.get("type") == "object":
                value["additionalProperties"] = False
            for child in value.values():
                fix_objects(child)
        elif isinstance(value, list):
            for child in value:
                fix_objects(child)

    fix_objects(result)
    return result


def _json_completion(prompt: str, schema: type, temperature: float):
    response = _client().chat.completions.create(
        model=MODEL,
        messages=[{"role": "user", "content": prompt}],
        response_format={
            "type": "json_schema",
            "json_schema": {
                "name": schema.__name__,
                "strict": True,
                "schema": _strict_schema(schema),
            },
        },
        temperature=temperature,
    )
    return schema.model_validate_json(response.choices[0].message.content)


def _retry(prompt: str, schema: type, temperature: float, max_retries: int):
    for attempt in range(max_retries + 1):
        try:
            return _json_completion(prompt, schema, temperature)
        except Exception as error:
            if attempt >= max_retries:
                raise Exception(f"Gagal memanggil OpenAI API setelah {max_retries} kali retry: {error}") from error
            print(f"[AI Service] OpenAI gagal. Mencoba lagi dalam 3 detik... (Percobaan ke-{attempt + 2})")
            time.sleep(3)


def summarize_section(text_chunk: str, max_retries: int = 2) -> SectionSummary:
    prompt = f"""
Kamu adalah asisten dosen yang ahli dalam meringkas materi kuliah.
Analisis teks materi berikut dan buat ringkasan terstruktur dalam Bahasa Indonesia.

Materi:
{text_chunk}
"""
    return _retry(prompt, SectionSummary, 0.3, max_retries)


def generate_overview(sections: list[SectionSummary], max_retries: int = 2) -> str:
    combined_text = "".join(
        f"\nBagian {idx + 1}: {section.title}\nPoin: {', '.join(section.key_points)}\n"
        for idx, section in enumerate(sections)
    )
    prompt = f"""
Kamu adalah dosen. Buat satu paragraf overview Bahasa Indonesia, maksimal 3-4 kalimat,
berdasarkan materi berikut:
{combined_text}
"""
    return _retry(prompt, OverviewResponse, 0.4, max_retries).overview


def generate_flashcards(summary_text: str, max_retries: int = 2) -> list[dict]:
    prompt = f"""
Kamu adalah AI Tutor. Buat maksimal 10 flashcard Bahasa Indonesia dari materi berikut.
Sisi depan berisi pertanyaan atau istilah, sisi belakang berisi jawaban atau definisi.

Materi:
{summary_text}
"""
    result = _retry(prompt, FlashcardList, 0.4, max_retries)
    return [card.model_dump() for card in result.flashcards]


def generate_quiz_questions(summary_text: str, amount: int, difficulty: str, max_retries: int = 2) -> list[dict]:
    prompt = f"""
Kamu adalah dosen penguji. Buat {amount} soal pilihan ganda Bahasa Indonesia tingkat kesulitan
{difficulty} berdasarkan materi berikut. Setiap soal harus punya tepat 4 opsi, index jawaban benar,
dan penjelasan.

Materi:
{summary_text}
"""
    result = _retry(prompt, QuizData, 0.4, max_retries)
    return [question.model_dump() for question in result.questions]


def get_chat_stream(context_text: str, chat_history: list[dict], new_message: str) -> Iterator:
    messages = [{
        "role": "system",
        "content": f"Kamu AI Tutor ramah. Jawab Bahasa Indonesia berdasarkan konteks materi.\n\nKonteks:\n{context_text}",
    }]
    messages.extend({"role": "assistant" if item["role"] == "assistant" else "user", "content": item["content"]} for item in chat_history)
    messages.append({"role": "user", "content": new_message})
    stream = _client().chat.completions.create(model=MODEL, messages=messages, temperature=0.5, stream=True)
    for chunk in stream:
        text = chunk.choices[0].delta.content
        if text:
            yield text
