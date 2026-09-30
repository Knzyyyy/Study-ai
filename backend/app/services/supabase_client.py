from supabase import create_client, Client
from app.config import settings

if not settings.SUPABASE_URL or not settings.SUPABASE_SERVICE_KEY:
    raise ValueError("SUPABASE_URL atau SUPABASE_SERVICE_KEY belum diisi di .env")

# Kita menggunakan Service Key agar backend punya hak akses penuh (bypass RLS)
# untuk memproses data di background. Keamanan tetap terjamin karena
# Flutter hanya bisa mengakses data miliknya lewat JWT Auth.
supabase: Client = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_KEY)