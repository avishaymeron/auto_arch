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

  const handleLearnDoc = async () => {
    try {
      const response = await axios.get('http://localhost:8000/table-of-contents');
      setTableOfContents(response.data);
    } catch (error) {
      console.error("Error fetching table of contents:", error);
    }
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
    <h1 className="logo-text">Estimator Assistant</h1>
      <div className="header">
        <img src="https://www.standard-textile.fr/build/images/logo-a.webp" alt="Auto Arch Logo" className="logo" />
        <img src="https://www.standard-textile.fr/build/images/logo-st.webp" alt="Auto Arch Logo" className="logo2" />
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
                  <li key={index} style={{ paddingLeft: `${item.level * 10}px` }}>
                    {item.title} (Page {item.page})
                  </li>
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
