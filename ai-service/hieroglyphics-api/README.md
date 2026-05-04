# Tourasna Hieroglyphics Translator API

> AI-powered hieroglyphic inscription translator built for the **Tourasna** Egyptian tourism app.
> 
> Tourists capture a photo of a hieroglyphic inscription → the API detects each glyph, orders them correctly, and produces a bilingual (English + Arabic) translation with historical context.

[![Python](https://img.shields.io/badge/Python-3.11-blue)](https://www.python.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115-009688)](https://fastapi.tiangolo.com/)
[![Tests](https://img.shields.io/badge/tests-40%20passing-success)](#testing)
[![License](https://img.shields.io/badge/license-Academic-yellow)](#)

---

## 🎯 Overview

This service is the **AI brain** of the Tourasna app's hieroglyphics translation feature. It exposes a REST API that the NodeJS backend consumes on behalf of the Flutter mobile client.

### Key Features

- 🔍 **Glyph Detection** — YOLOv8m trained on 32K images across 767 Gardiner classes
- 📐 **Smart Reading Order** — Quadrat-based algorithm supporting RTL/LTR/TTB
- 🤖 **Hybrid 4-Layer Translation** — Database → LLM → Transformer → Sign meanings
- 🌍 **Bilingual Output** — English + Arabic translations with historical context
- ✏️ **Interactive Correction** — Human-in-the-Loop API for fixing detection errors
- 🛡️ **Honest AI** — LLM uses confidence levels; never hallucinates

---

## 🏗️ Architecture
┌─────────────────────────────────────────────────────────────┐
│                  Tourist's Photo                             │
│                       ↓                                      │
│  ┌─────────────────────────────────────────────┐            │
│  │  Stage 1: Detector v2 (YOLOv8m)             │            │
│  │  → 767 Gardiner classes, 32K training imgs  │            │
│  │  → Output: bounding boxes + Gardiner codes  │            │
│  └─────────────────────────────────────────────┘            │
│                       ↓                                      │
│  ┌─────────────────────────────────────────────┐            │
│  │  Stage 2: Smart Sorter                       │            │
│  │  → Quadrat-based reading order              │            │
│  │  → Supports RTL / LTR / TTB                 │            │
│  └─────────────────────────────────────────────┘            │
│                       ↓                                      │
│  ┌─────────────────────────────────────────────┐            │
│  │  Stage 3: Hybrid Translator (4 layers)       │            │
│  │                                              │            │
│  │  Layer 1: Database — 32 curated phrases     │            │
│  │           (Ramesses, Tut, Hatshepsut, ...)  │            │
│  │                                              │            │
│  │  Layer 2: LLM (Groq + Llama 3.3 70B)        │            │
│  │           Honest, grammatical, bilingual    │            │
│  │                                              │            │
│  │  Layer 3: Transformer (Seq2Seq, BLEU 7.76)  │            │
│  │           Offline fallback                  │            │
│  │                                              │            │
│  │  Layer 4: Sign meanings (per-sign breakdown)│            │
│  │           Always succeeds                   │            │
│  └─────────────────────────────────────────────┘            │
│                       ↓                                      │
│              Bilingual JSON Response                         │
│         (EN + AR + Transliteration + Context)                │
└─────────────────────────────────────────────────────────────┘

---

## 🚀 Quick Start

### Prerequisites

- Python **3.11**
- 4 GB+ RAM
- 1 GB disk space (for models)

### 1. Clone and enter the project

```bash
cd ai-service/hieroglyphics-api
```

### 2. Create virtual environment

```bash
# Windows
python -m venv venv
venv\Scripts\activate

# Linux / macOS
python3 -m venv venv
source venv/bin/activate
```

### 3. Install dependencies

```bash
pip install -r requirements.txt
```

### 4. Set up environment variables

```bash
# Copy the template
copy .env.example .env       # Windows
cp .env.example .env         # Linux/Mac

# Edit .env and add your API keys:
#   GROQ_API_KEY=...   (required for LLM Layer 2)
```

> ℹ️ **Get a Groq API key** (free): https://console.groq.com/keys

### 5. Download models

The trained models (~200 MB) are stored on Google Drive — see [docs/MODELS.md](docs/MODELS.md) for download instructions and the expected directory structure.

### 6. Run the server

```bash
uvicorn api.main:app --host 0.0.0.0 --port 8000
```

The API is now live at **http://localhost:8000**.

- 📖 **Interactive Docs (Swagger UI):** http://localhost:8000/docs
- 🎨 **Demo Web Page:** http://localhost:8000/demo
- ❤️ **Health Check:** http://localhost:8000/api/health

---

## 📡 API Endpoints

| Method | Endpoint                       | Description                                      |
|--------|--------------------------------|--------------------------------------------------|
| GET    | `/api/health`                  | Service health check                             |
| POST   | `/api/translate`               | Detect & translate from an image (full pipeline) |
| POST   | `/api/translate-codes`         | Translate a sequence of Gardiner codes           |
| POST   | `/api/translate-corrected`     | Translate user-corrected sequence (HITL)         |
| GET    | `/api/signs`                   | List all known Gardiner signs (64)               |
| GET    | `/api/sign/{code}/info`        | Detailed info for a single sign                  |
| GET    | `/api/signs/search`            | Search signs by code, name, or transliteration   |

> 📚 **Full API documentation with request/response examples:** [docs/API.md](docs/API.md)

---

## 🧪 Testing

40 integration tests covering all endpoints:

```bash
# Run all tests
pytest -v

# Run with coverage
pytest --cov=api --cov-report=term-missing
```

Test categories:
- ✅ Health checks (5)
- ✅ Reference data (5)
- ✅ Translation pipeline (5 + 7)
- ✅ Interactive correction (13)
- ✅ Translation corrected (5)

---

## 🛠️ Tech Stack

| Component          | Technology                              |
|--------------------|-----------------------------------------|
| Web Framework      | FastAPI 0.115 + Uvicorn                 |
| Detection          | Ultralytics YOLOv8                      |
| Translation        | PyTorch (Seq2Seq Transformer) + SentencePiece (BPE) |
| LLM                | Groq Cloud API + Llama 3.3 70B          |
| Validation         | Pydantic v2                             |
| Logging            | Loguru                                  |
| Testing            | pytest + pytest-asyncio                 |
| Image Processing   | Pillow                                  |

---

## 📂 Project Structure
hieroglyphics-api/
├── api/                          # FastAPI application
│   ├── main.py                   # Entry point
│   ├── config.py                 # Settings (Pydantic)
│   ├── routes/                   # HTTP endpoints
│   ├── services/                 # Business logic
│   │   ├── detector_service.py
│   │   ├── sorter_service.py
│   │   ├── translator_service.py
│   │   ├── llm_translator_service.py
│   │   └── sign_info_service.py
│   └── schemas/                  # Pydantic models
├── data/                         # Static data (JSON files)
│   ├── translations_db.json      # 32 curated phrases
│   └── sign_extended_info.json   # Sign metadata
├── models/                       # Trained models (gitignored)
│   ├── detector/best.pt
│   └── translator/best_translator.pth
├── tests/                        # pytest test suite
├── scripts/                      # Utility scripts
├── static/                       # Demo web page
└── docs/                         # Documentation
├── API.md
└── MODELS.md

---

## 🤝 Integration Guide (NodeJS Backend)

The NodeJS backend acts as a **proxy** between the Flutter app and this service. Example:

```javascript
// In your NodeJS backend
const FormData = require('form-data');
const axios = require('axios');

async function translateInscription(imageBuffer) {
    const form = new FormData();
    form.append('image', imageBuffer, 'inscription.jpg');
    form.append('reading_direction', 'rtl');
    
    const response = await axios.post(
        'http://hieroglyphics-api:8000/api/translate',
        form,
        { headers: form.getHeaders() }
    );
    
    return response.data;
}
```

> 📖 See [docs/API.md](docs/API.md) for full request/response schemas.

---

## 🔐 Environment Variables

| Variable           | Required | Description                                       |
|--------------------|----------|---------------------------------------------------|
| `GROQ_API_KEY`     | Optional | Enables LLM Layer 2. Without it, falls through to Transformer (Layer 3) |
| `HOST`             | No       | Server host (default: `0.0.0.0`)                  |
| `PORT`             | No       | Server port (default: `8000`)                     |
| `DEBUG`            | No       | Enable debug mode (default: `false`)              |
| `DEVICE`           | No       | `cuda`, `cpu`, or `auto` (default: `auto`)        |

> 📋 See `.env.example` for the full list of configurable settings.

---

## 📚 Documentation

- 📖 [API Reference](docs/API.md) — Full endpoint documentation with examples
- 📦 [Models Setup](docs/MODELS.md) — How to download and place models
- 🌐 Interactive API docs: http://localhost:8000/docs (when running)

---

## 🎓 Academic Context

This service is part of **Tourasna**, a graduation project at **Nile University**, demonstrating:

- Multi-stage AI pipeline orchestration
- Hybrid AI architectures (rule-based + LLM + Transformer)
- Production-ready REST APIs with FastAPI
- Honest AI design (uncertainty quantification)
- Human-in-the-Loop correction patterns

**Authors:** Tourasna team  
**Year:** 2026  
**License:** Academic use only

---

## 🐛 Troubleshooting

### Models not found
FileNotFoundError: models/detector/best.pt
→ Download models from Google Drive — see [docs/MODELS.md](docs/MODELS.md).

### LLM disabled at startup
WARNING: LLM translator disabled: GROQ_API_KEY not set
→ The system still works using Transformer (Layer 3). Add `GROQ_API_KEY` to `.env` to enable Layer 2.

### Port 8000 already in use
```bash
uvicorn api.main:app --port 8001
```

### Import errors
```bash
# Ensure venv is activated
venv\Scripts\activate     # Windows
source venv/bin/activate  # Linux/Mac

# Reinstall dependencies
pip install -r requirements.txt --force-reinstall
```