#!/bin/bash

# Exit on error
set -e

echo "Creating auto_arch project structure..."

# Create project directories
mkdir -p frontend/src/components
mkdir -p frontend/src/styles
mkdir -p frontend/public
mkdir -p backend/app
mkdir -p backend/tests

# Create Python virtual environment
echo "Creating Python virtual environment..."
python3.11 -m venv venv
. venv/bin/activate

# Install Python dependencies
echo "Installing Python dependencies..."
cat > backend/requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn==0.24.0
python-multipart==0.0.6
PyMuPDF==1.23.7  # For PDF processing
numpy==1.26.2    # For numerical operations
pydantic==2.5.2  # For data validation
pytest==7.4.3    # For testing
python-jose==3.3.0  # For JWT tokens
passlib==1.7.4   # For password hashing
python-dotenv==1.0.0
EOF

pip install -r backend/requirements.txt

# Create backend FastAPI application
cat > backend/app/main.py << 'EOF'
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
EOF


# Create frontend package.json
cat > frontend/package.json << 'EOF'
{
  "name": "auto-arch-frontend",
  "version": "0.1.0",
  "private": true,
  "dependencies": {
    "@react-pdf-viewer/core": "3.11.0",
    "@react-pdf-viewer/default-layout": "3.11.0",
    "@react-pdf-viewer/zoom": "3.11.0",
    "pdfjs-dist": "3.11.174",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "5.0.1",
    "axios": "^1.6.2"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "eslintConfig": {
    "extends": [
      "react-app"
    ]
  },
  "browserslist": {
    "production": [
      ">0.2%",
      "not dead",
      "not op_mini all"
    ],
    "development": [
      "last 1 chrome version",
      "last 1 firefox version",
      "last 1 safari version"
    ]
  }
}
EOF

# Create React components
cat > frontend/src/App.js << 'EOF'
import React, { useState } from 'react';
import { Worker, Viewer } from '@react-pdf-viewer/core';
import { defaultLayoutPlugin } from '@react-pdf-viewer/default-layout';
import { zoomPlugin } from '@react-pdf-viewer/zoom';

// Import the styles
import '@react-pdf-viewer/core/lib/styles/index.css';
import '@react-pdf-viewer/default-layout/lib/styles/index.css';
import '@react-pdf-viewer/zoom/lib/styles/index.css';

import axios from 'axios';
import './styles/App.css';

const App = () => {
  const [pdfFile, setPdfFile] = useState(null);
  const [measurements, setMeasurements] = useState(null);
  const [measurementMode, setMeasurementMode] = useState(false);
  const [measurePoints, setMeasurePoints] = useState([]);
  const [tableOfContents, setTableOfContents] = useState([]);

  const defaultLayoutPluginInstance = defaultLayoutPlugin();
  const zoomPluginInstance = zoomPlugin();

  const handleFileChange = async (e) => {
    const file = e.target.files[0];
    if (file) {
      const formData = new FormData();
      formData.append('file', file);
      
      try {
        await axios.post('http://localhost:8000/upload', formData);
        setPdfFile(URL.createObjectURL(file));
      } catch (error) {
        console.error('Error uploading PDF:', error);
      }
    }
  };

  const handleMeasureClick = () => {
    setMeasurementMode(!measurementMode);
    setMeasurePoints([]);
  };

  const handleLearnDoc = () => {
    // Implementation will be added later
    console.log("Learn Doc clicked");
  };

  const handlePageClick = async (e) => {
    if (!measurementMode) return;

    const rect = e.target.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    
    const newPoints = [...measurePoints, { x, y }];
    setMeasurePoints(newPoints);

    if (newPoints.length === 2) {
      try {
        const response = await axios.post('http://localhost:8000/measure', {
          page_num: 0,
          x1: newPoints[0].x,
          y1: newPoints[0].y,
          x2: newPoints[1].x,
          y2: newPoints[1].y,
        });
        setMeasurements(response.data);
        setMeasurePoints([]);
      } catch (error) {
        console.error('Error measuring:', error);
      }
    }
  };

  return (
    <div className="container">
      <div className="header">
        <img src="logo.jpg" alt="Auto Arch Logo" className="logo" />
        <h1 className="logo-text">Auto Arch</h1>

      <div className="toolbar">
        <input type="file" accept=".pdf" onChange={handleFileChange} />
        <button onClick={handleMeasureClick}>
          {measurementMode ? 'Cancel Measure' : 'Measure'}
        </button>
        <button onClick={handleLearnDoc}>Learn Doc</button>
      </div>
    </div>
      <div className="main-content">
        <div className="left-panel">
          <div className="frame toc-frame">
            <h3>Table of Contents</h3>
            {tableOfContents.length > 0 ? (
              <ul>
                {tableOfContents.map((item, index) => (
                  <li key={index}>{item.title}</li>
                ))}
              </ul>
            ) : (
              <p>No content available. Click "Learn Doc" to analyze the document.</p>
            )}
          </div>
          
          <div className="frame data-table-frame">
            <h3>Data Table</h3>
            <table className="data-table">
              <thead>
                <tr>
                  <th>Column 1</th>
                  <th>Column 2</th>
                  <th>Column 3</th>
                  <th>Column 4</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td></td>
                  <td></td>
                  <td></td>
                  <td></td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div className="viewer-container">
          {measurements && (
            <div className="measurements">
              <h3>Measurements:</h3>
              <p>Width: {measurements.width.toFixed(2)}</p>
              <p>Height: {measurements.height.toFixed(2)}</p>
              <p>Diagonal: {measurements.diagonal.toFixed(2)}</p>
            </div>
          )}
          
          {pdfFile && (
            <div className="viewer" onClick={handlePageClick}>
              <Worker workerUrl="https://unpkg.com/pdfjs-dist@3.11.174/build/pdf.worker.min.js">
                <Viewer
                  fileUrl={pdfFile}
                  plugins={[defaultLayoutPluginInstance, zoomPluginInstance]}
                />
              </Worker>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default App;
EOF

# Create frontend index.js
cat > frontend/src/index.js << 'EOF'
import React from 'react';
import { createRoot } from 'react-dom/client';
import './styles/App.css';
import App from './App';

const container = document.getElementById('root');
const root = createRoot(container);
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF

# Create CSS styles
cat > frontend/src/styles/App.css << 'EOF'
.container {
  display: flex;
  flex-direction: column;
  height: 98vh;
  padding: 10px;
  overflow: hidden; /* Prevent scrolling on the container */
  box-sizing: border-box; /* Makes padding part of the element's total width/height */
}

.header {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 0px;
}

.logo {
  width: 70px;
  height: 70px;
  object-fit: contain;
}

.logo2 {
  width: 120px;
  height: 120px;
  object-fit: contain;

}

.logo-text {
  font-size: 24px;
  font-weight: bold;
  color: #007bff;
  margin: 0;
}

.main-content {
  display: flex;
  flex: 1;
  gap: 10px;
  overflow: hidden; /* Prevent main content from scrolling */
  height: calc(100vh - 150px); /* Subtract header height + padding + margins */
  box-sizing: border-box;
}

.left-panel {
  width: 300px;
  display: flex;
  flex-direction: column;
  gap: 20px;
  overflow: hidden; /* Prevent scrolling on the container */
  height: 100%; /* Take full height of main-content */
}

.frame {
  background: white;
  border: 1px solid #ccc;
  border-radius: 5px;
  padding: 0px;
  flex: 1;
  overflow: auto;
}

.toc-frame {
  min-height: 300px;
  flex: 1;
}

.data-table-frame {
  min-height: 300px;
  flex: 1;
  
}

.viewer-container {
  flex: 1;
  display: flex;
  flex-direction: column;
  max-height: 100%;
  position: relative; /* For measurements positioning */
}

.toolbar {
  display: flex;
  gap: 10px;
  margin-bottom: 10px;
}

.viewer {
  flex: 1;
  border: 1px solid #ccc;
  border-radius: 5px;
  overflow: auto; /* THIS enables scrolling within the PDF viewer only */
  max-height: 100%; /* Ensure it doesn't exceed parent container */
  box-sizing: border-box;
}

.measurements {
  position: fixed;
  top: 20px;
  right: 20px;
  background: white;
  padding: 15px;
  border: 1px solid #ccc;
  border-radius: 5px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  overflow: auto; /* THIS is the key - allow PDF viewer to scroll independently */
}

button {
  padding: 8px 16px;
  background-color: #007bff;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
}

button:hover {
  background-color: #0056b3;
}

.data-table {
  width: 100%;
  border-collapse: collapse;
}

.data-table th,
.data-table td {
  border: 1px solid #ddd;
  padding: 0px;
  text-align: left;
}

.data-table th {
  background-color: #f5f5f5;
  font-weight: bold;
}

.data-table tr:nth-child(even) {
  background-color: #f9f9f9;
}

# Create index.html
cat > frontend/public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Auto Arch - PDF Measurement Tool</title>
  </head>
  <body>
    <div id="root"></div>
  </body>
</html>
EOF

# Create Makefile
cat > Makefile << 'EOF'
SHELL := /bin/bash  # Specify bash as the shell

.PHONY: install run-backend run-frontend run-all

install:
	# Install frontend dependencies
	cd frontend && npm install
	# Install backend dependencies
	. venv/bin/activate && pip install -r backend/requirements.txt

run-backend:
	. venv/bin/activate && cd backend && uvicorn app.main:app --reload --port 8000

run-frontend:
	cd frontend && npm start

run-all:
	@echo "Starting all services..."
	@gnome-terminal --tab --title="Backend" -- bash -c "make run-backend"
	@gnome-terminal --tab --title="Frontend" -- bash -c "make run-frontend"
EOF

# Install frontend dependencies
echo "Installing frontend dependencies..."
cd frontend && npm install && cd ..

# Make the script executable
chmod +x create_all.sh

echo "Project setup complete! You can now run 'make run-all' to start both frontend and backend servers."
