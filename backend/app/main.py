from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi import Depends
from app.auth import get_current_user
from app.routers import materials
from app.routers import materials, flashcards  # Tambahkan flashcards di sini
from app.routers import materials, flashcards, quiz  # Tambahkan quiz di sini
from app.routers import materials, flashcards, quiz, chat  # Tambahkan chat
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
# import router lain di sini...

# Inisialisasi aplikasi FastAPI
app = FastAPI(
    title="AI Tutor Backend",
    description="API untuk memproses materi kuliah dan AI Tutor",
    version="1.0.0"
)

# Konfigurasi CORS (Agar Flutter bisa memanggil API ini tanpa diblokir)
app.add_middleware(
    CORSMiddleware,
    allow_origins=[],
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mendaftarkan rute (router) materials
app.include_router(materials.router)
app.include_router(materials.router)
app.include_router(flashcards.router) # Tambahkan baris ini
app.include_router(materials.router)
app.include_router(flashcards.router)
app.include_router(quiz.router) # Tambahkan baris ini
app.include_router(materials.router)
app.include_router(flashcards.router)
app.include_router(quiz.router)
app.include_router(chat.router) # Tambahkan baris ini

# Endpoint pertama (untuk mengetes server hidup/tidak)
@app.get("/")
def read_root():
    return {"message": "Selamat datang di API AI Tutor!", "status": "running"}

# Endpoint untuk cek kesehatan server
@app.get("/health")
def health_check():
    return {"status": "ok"}

# Endpoint ini dilindungi! Wajib bawa token JWT.
@app.get("/me")
def get_my_profile(user = Depends(get_current_user)):
    return {
        "message": "Token valid! Akses diizinkan.", 
        "user_id": user.id,
        "email": user.email
    }