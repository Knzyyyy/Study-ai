from app.services.chunker import chunk_material_pages
from app.services.ai_service import summarize_section, generate_overview

def process_material_text(pages: list[dict]) -> dict:
    """
    Fungsi utama (Map-Reduce) untuk memproses teks halaman menjadi ringkasan akhir.
    Format output disesuaikan dengan kebutuhan kolom 'summaries' di Supabase.
    """
    if not pages:
        raise ValueError("Tidak ada teks yang bisa diproses.")

    print("[Summarizer] Memotong teks (Chunking)...")
    chunks = chunk_material_pages(pages, max_tokens=3000)
    
    sections = []
    all_key_terms = []
    
    # PROSES MAP: Ringkas per chunk
    for i, chunk in enumerate(chunks):
        print(f"[Summarizer] Meringkas bagian {i+1} dari {len(chunks)}...")
        section_summary = summarize_section(chunk)
        sections.append(section_summary)
        
        # Kumpulkan semua istilah penting tanpa duplikat (berdasarkan nama istilah)
        for term in section_summary.key_terms:
            # Cek apakah istilah sudah ada di list
            if not any(t["term"].lower() == term.term.lower() for t in all_key_terms):
                all_key_terms.append({"term": term.term, "definition": term.definition})

    # PROSES REDUCE: Buat Overview
    print("[Summarizer] Membuat overview keseluruhan...")
    overview = generate_overview(sections)
    
    # Kembalikan data dalam format yang siap disimpan ke database (JSON)
    return {
        "overview": overview,
        "sections": [sec.model_dump() for sec in sections],
        "key_terms": all_key_terms
    }