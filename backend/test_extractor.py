from app.services.extractor import extract_text_from_pdf, extract_text_from_pptx

def test_extraction(file_path: str):
    print(f"\n--- Memproses file: {file_path} ---")
    
    try:
        if file_path.lower().endswith('.pdf'):
            pages = extract_text_from_pdf(file_path)
        elif file_path.lower().endswith('.pptx'):
            pages = extract_text_from_pptx(file_path)
        else:
            print("Format tidak didukung!")
            return

        print(f"Berhasil mengekstrak {len(pages)} halaman/slide.")
        
        # Tampilkan teks dari 2 halaman pertama saja agar terminal tidak kepenuhan
        for page in pages[:2]:
            print(f"\n[Halaman {page['page_number']}]")
            print("-" * 30)
            # Potong teks maks 200 karakter agar enak dibaca
            print(page['content_text'][:200] + ("..." if len(page['content_text']) > 200 else ""))
            print("-" * 30)
            
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    # Ganti nama file ini dengan file PDF atau PPTX yang kamu punya di folder backend
    pdf_file = "sample.pdf"
    pptx_file = "sample.pptx"
    
    # Buat file dummy/copy file kuliahmu ke folder backend lalu jalankan ini
    test_extraction(pdf_file)
    test_extraction(pptx_file)