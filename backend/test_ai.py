import os
import json
from dotenv import load_dotenv
from app.services.extractor import extract_text_from_pdf
from app.services.summarizer import process_material_text

load_dotenv()

def test_full_pipeline():
    file_path = "sample.pdf"
    
    if not os.path.exists(file_path):
        print(f"File {file_path} tidak ada.")
        return

    try:
        print("1. Ekstrak PDF...")
        pages = extract_text_from_pdf(file_path)
        
        print("2. Memulai pipeline Summarizer (Map-Reduce)...")
        final_summary = process_material_text(pages)
        
        print("\n" + "="*50)
        print("🎉 HASIL AKHIR (SIAP MASUK DATABASE) 🎉")
        print("="*50)
        
        print("\n[OVERVIEW]")
        print(final_summary["overview"])
        
        print(f"\n[SECTIONS] -> {len(final_summary['sections'])} bagian ditemukan.")
        print(f"[KEY TERMS] -> {len(final_summary['key_terms'])} istilah unik dikumpulkan.")
        
        # Tampilkan JSON mentah sebagian agar kelihatan strukturnya
        print("\n[JSON PREVIEW]")
        print(json.dumps(final_summary, indent=2, ensure_ascii=False)[:500] + "\n... (dipotong agar tidak kepanjangan)")
            
    except Exception as e:
        print(f"Error Pipeline: {e}")

if __name__ == "__main__":
    test_full_pipeline()