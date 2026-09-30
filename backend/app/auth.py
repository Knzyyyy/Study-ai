from fastapi import Security, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.services.supabase_client import supabase

# HTTPBearer akan otomatis mengekstrak token dari header: "Authorization: Bearer <token>"
security = HTTPBearer()

def get_current_user(credentials: HTTPAuthorizationCredentials = Security(security)):
    """
    Fungsi ini akan otomatis dipanggil di setiap endpoint yang butuh login.
    Fungsinya: mengambil token, mengirimnya ke Supabase untuk dicek, 
    lalu mengembalikan data user_id jika valid.
    """
    token = credentials.credentials
    
    try:
        # Minta Supabase memverifikasi JWT token ini
        user_response = supabase.auth.get_user(token)
        
        if not user_response or not user_response.user:
            raise Exception("User tidak ditemukan")
            
        # Mengembalikan object user (berisi id, email, dll)
        return user_response.user
        
    except Exception as e:
        # Jika token palsu, expired, atau rusak, lemparkan error 401 Unauthorized
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Akses ditolak. Token tidak valid: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )