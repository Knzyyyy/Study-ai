def chunk_material_pages(pages: list[dict], max_tokens: int = 3000) -> list[str]:
    """
    Menggabungkan teks dari tiap halaman lalu membaginya menjadi chunk.
    Satu token ~ 4 karakter, jadi max_chars = max_tokens * 4.
    """
    max_chars = max_tokens * 4
    chunks = []
    current_chunk = ""

    for page in pages:
        text = page["content_text"]
        # Jika chunk saat ini + halaman baru melebihi batas, simpan chunk lama, mulai baru
        if len(current_chunk) + len(text) > max_chars and current_chunk:
            chunks.append(current_chunk.strip())
            current_chunk = text + "\n\n"
        else:
            current_chunk += text + "\n\n"

    # Masukkan sisa teks terakhir jika ada
    if current_chunk.strip():
        chunks.append(current_chunk.strip())

    return chunks