from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import fitz  # PyMuPDF
import os
from typing import List
import numpy as np

app = FastAPI()

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class PDFProcessor:
    def __init__(self):
        self.current_doc = None
        
    def load_pdf(self, file_path: str):
        self.current_doc = fitz.open(file_path)
        #raise HTTPException(status_code=400, detail="PDF was loaded")
        
    def get_page_dimensions(self, page_num: int):
        if not self.current_doc:
            raise HTTPException(status_code=400, detail="No PDF loaded")
        page = self.current_doc[page_num]
        return {"width": page.rect.width, "height": page.rect.height}
        
    def measure_element(self, page_num: int, x1: float, y1: float, x2: float, y2: float):
        if not self.current_doc:
            raise HTTPException(status_code=400, detail="No PDF loaded")
        width = abs(x2 - x1)
        height = abs(y2 - y1)
        return {"width": width, "height": height, "diagonal": np.sqrt(width**2 + height**2)}
    
    def get_table_of_contents(self):
        if not self.current_doc:
            raise HTTPException(status_code=400, detail="No PDF loaded")
        
        #toc = self.current_doc.get_toc()  # Get table of contents
        #toc=[["1", "Page", "2"], ["1", "Page", "2"]]
        toc_list = [{"level": "1", "title": "This is a test",  "page": "1"}]
    
        return toc_list

pdf_processor = PDFProcessor()

@app.post("/upload")
async def upload_pdf(file: UploadFile = File(...)):
    
    try:
        # Save uploaded file temporarily
        temp_path = f"temp_{file.filename}"
        with open(temp_path, "wb") as buffer:
            content = await file.read()
            buffer.write(content)

        # Load PDF
        pdf_processor.load_pdf(temp_path)
        # Clean up temp file
        os.remove(temp_path)
        
        return {"message": "PDF loaded successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/dimensions/{page_num}")
async def get_dimensions(page_num: int):
    return pdf_processor.get_page_dimensions(page_num)

@app.post("/measure")
async def measure_element(page_num: int, x1: float, y1: float, x2: float, y2: float):
    return pdf_processor.measure_element(page_num, x1, y1, x2, y2)

@app.get("/table-of-contents")
async def get_table_of_contents():
    return pdf_processor.get_table_of_contents()
