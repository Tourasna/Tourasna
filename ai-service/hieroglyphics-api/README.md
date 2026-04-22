\# Tourasna Hieroglyphics Translator API



AI-powered hieroglyphic inscription translator built for the Tourasna Egyptian tourism app.



\## Pipeline

1\. \*\*Detector v2\*\* (YOLOv8m, 767 Gardiner classes) - Detect and classify glyphs

2\. \*\*Smart Sorter\*\* (Quadrat-based) - Order glyphs by reading direction

3\. \*\*Hybrid Translator\*\* (3 layers: Database -> Transformer -> Sign meanings)



\## Tech Stack

\- FastAPI + Uvicorn

\- PyTorch + Ultralytics YOLOv8

\- SentencePiece (BPE tokenizer)



\## Setup



\### 1. Create virtual environment

python -m venv venv

venv\\Scripts\\activate



\### 2. Install dependencies

pip install -r requirements.txt



\### 3. Copy environment template

copy .env.example .env



\### 4. Download models

Download models from Google Drive and place in the `models/` folder.

See `DEPLOYMENT.md` for details.



\### 5. Run the API

uvicorn api.main:app --reload



\## API Docs

Once running, visit http://localhost:8000/docs for interactive Swagger UI.



\## Architecture

See detailed architecture notes in `docs/architecture.md` (coming soon).

