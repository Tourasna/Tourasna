# 𓅓 Tourasna | تُرَاثُنَا

> **Graduation Project — CSCI496: Senior Project II**
> **Team:** Alia Mostafa · Fady Farouk · Hassan Sabry · Hossamaldeen Elghazaly · Moaz Elkhashab · Youssef Maged
> **Supervisors:** Dr. Noha Gamal Eldin & Dr. Mohamed ElHelw — Nile University, Faculty of CS, Spring 2026

---

## Table of Contents

1. [Overview](#overview)
2. [Key Features](#key-features)
3. [System Architecture](#system-architecture)
4. [AI Modules](#ai-modules)
5. [Repository Structure](#repository-structure)
6. [Tech Stack](#tech-stack)
7. [Requirements](#requirements)
8. [Installation](#installation)
   - [Flutter Application](#flutter-application)
   - [NestJS Backend](#nestjs-backend)
   - [FastAPI AI Service](#fastapi-ai-service)
   - [Docker Compose Deployment](#docker-compose-deployment)
   - [Modal GPU Endpoints](#modal-gpu-endpoints)
9. [Environment Variables](#environment-variables)
10. [API Reference](#api-reference)
11. [Database Schema](#database-schema)
12. [AWS S3 Structure](#aws-s3-structure)
13. [AI Module Performance](#ai-module-performance)
14. [Known Limitations](#known-limitations)
15. [Team](#team)

---

## Overview

**Tourasna** (تُرَاثُنَا — *Our Heritage*) is an AI-powered smart cultural tourism platform targeting the heritage landscape of Greater Cairo and Giza. It integrates seven coordinated AI services within a single Android application, enabling visitors to identify monuments, translate ancient hieroglyphics, generate 3D models, plan personalized itineraries, and interact with an intelligent heritage chatbot — all from one unified mobile experience.

The system was built as a graduation project at Nile University (2025–2026) in response to a clear gap in Egypt's digital heritage infrastructure: no single application combines monument recognition, AI-generated storytelling, 3D visualization, hieroglyphic translation, personalized recommendations, conversational assistance, and smart trip planning.

---

## Key Features

| Feature | Description |
|---|---|
| 📸 **AI Lens** | On-device real-time monument recognition across 127 Egyptian heritage classes using YOLOv8s TFLite |
| 🔤 **Hieroglyphics Translator** | Detect and translate ancient glyphs via YOLOv8m + 4-layer hybrid pipeline (DB → LLM → Transformer → Fallback) |
| 🏛️ **3D Monument Viewer** | AI-generated 3D models via Hunyuan3D-2 on Modal A100 GPU, streamed progressively to the Flutter WebView |
| 🎙️ **AI Storytelling** | Groq LLaMA 3.3 70B narrative generation with Google TTS Chirp 3 HD synthesis across 31 languages |
| 🤖 **FAHMY Chatbot** | Mistral-7B with FAISS RAG over 677 landmarks, supporting 16 languages via WebSocket token streaming |
| 🗺️ **Interactive Map** | Real-time GPS tracking, proximity-based storytelling triggers, and deep-linked external navigation |
| 📅 **Trip Planner** | DayPlan (top 10) and TripPlan (5/day, up to 14 days) with time-conflict detection in the agenda |
| ⭐ **Recommendations** | Dual-tower neural network (29,313 params) trained on 5M synthetic interactions with behavioral affinity learning |

---

## System Architecture

The system follows a strict layered, service-oriented architecture:

```
Flutter Mobile App (Android)
         │  REST + WebSocket (port 80)
         ▼
    nginx Reverse Proxy  ──────────────────────────────────────────────┐
         │                                                              │
    /api/* → NestJS API Gateway (port 3000)          /ai/* → FastAPI AI Service (port 8000)
         │                                                              │
    ┌────┴───────────────────────┐                    ┌────────────────┴──────────────┐
    │ 12 NestJS Modules          │                    │ YOLOv8m Hieroglyphics         │
    │ MySQL 8.0 (TypeORM)        │                    │ Groq LLaMA 3.3 70B            │
    │ AWS S3 (IMDSv2)            │                    │ Seq2Seq Transformer            │
    │ Firebase Auth Guard        │                    │ FastAPI + Uvicorn             │
    └────────────────────────────┘                    └───────────────────────────────┘
         │
    External Services
    ├── Firebase Authentication   (JWT issuance & verification)
    ├── Google Maps Flutter SDK   (Map rendering, routing, GPS)
    ├── Google TTS Chirp 3 HD     (Neural speech synthesis, called from Flutter)
    ├── Groq API (LLaMA 3.3 70B)  (Stories + hieroglyphic translation)
    ├── Modal A10G — Mistral-7B   (Chatbot, min_containers=1, always warm)
    ├── Modal A100 — Hunyuan3D-2  (3D shape + texture generation)
    └── AWS S3 (tourasna-assets)  (Photos, avatars, GLBs, 3D ref views)
```

All infrastructure runs on **AWS EC2 t3.small** (eu-north-1, IP: `13.50.201.36`) with Docker Compose managing three containers (NestJS, FastAPI, MySQL) on a private bridge network.

---

## AI Modules

### Monument Recognition — YOLOv8s TFLite
- **127 Egyptian heritage classes** (statues, pyramids, masks, temples, mosques, modern landmarks)
- Trained on **Finalized_Yolo_Dataset**: 32,587 image/label pairs (25,994 train / 3,922 valid / 2,671 test)
- Multi-session transfer-learning continuation from COCO-pretrained YOLOv8s checkpoint
- Exported to `best_float32.tflite` for on-device Flutter inference — **no network call for recognition**
- Output tensor: `[1, 131, 8400]` (4 box values + 127 class scores × 8400 anchors)

### Hieroglyphics Translator — 4-Layer Hybrid Pipeline
- **Detection:** YOLOv8m fine-tuned on 32,000+ annotated images across 767 Gardiner sign classes
- **Reading order:** Quadrat-based spatial clustering, user-selectable RTL / LTR / TTB
- **Translation layers (sequential fallback):**
  1. Curated phrase database (O(1) lookup, 32 cartouche/formula records)
  2. Groq LLaMA 3.3 70B with mandatory confidence disclosure and honesty-over-hallucination enforcement
  3. Custom Encoder-Decoder Transformer (11.8M params, BLEU 7.76 on BBAW Egyptian Corpus)
  4. Per-sign meaning fallback — guarantees a non-empty response for every valid input
- **Output:** Bilingual EN + AR translation, phonetic transliteration, historical context, per-sign breakdown

### 3D Reconstruction — Hunyuan3D-2 on Modal A100
- **Single-image and multi-view modes** (front + back S3 reference views for 127 classes)
- Shape generation: 50-step DiT denoising, guidance scale 7.5, Marching Cubes depth 6 → ~378K–580K vertices
- Texture generation: 2048×2048 UV atlas via multi-view diffusion UNet (async, 10–20 min)
- Progressive delivery: shape GLB returned in **20–45 s**, texture streamed via 30-second polling
- Cold-start handling: `COLD_RETRIES=14`, `COLD_WAIT_MS=30,000 ms`

### Recommendation Engine — Dual-Tower Neural Network
- **5,000,000 synthetic user–landmark interactions** (70/15/15 train/val/test split)
- User branch: `Input(39) → 128 → 64 → 32` with BN, Dropout, L2 regularization
- Landmark branch: `Input(31) → 64 → 32` with same regularization stack
- Interaction: DotProduct + ElementWiseProduct + Concatenation → `64 → 32 → 16 → 1 Sigmoid`
- Behavioral affinity: 27-dimensional affinity vector updated per like/dislike (+0.8 / −0.3), clipped to [0.05, 1.0]
- Cold-start blending: `dl_weight = max(0.20, interactions / (interactions + 20))`

### FAHMY Chatbot — Mistral-7B + FAISS RAG
- **677 Egyptian landmarks** indexed in FAISS IndexFlatIP (768-dim nomic-embed-text-v1.5 embeddings)
- Semantic retrieval: cosine similarity threshold 0.3, max 2 results per subcategory
- **16 supported languages** with two-tier detection (Unicode script analysis + lexical keyword matching)
- Validate-then-stream architecture: full response generated, language validated, then streamed at ~20 ms/token
- Persistent index: atomic disk writes (`knowledge_base.faiss`, `embeddings.pkl`) for sub-second reload

---

## Repository Structure

```
Tourasna/
│
├── flutter-app/                  # Flutter Android application
│   ├── lib/
│   │   ├── core/                 # ApiClient, AuthService, NetworkNavigator
│   │   ├── features/             # One directory per functional module
│   │   ├── pages/                # UI pages (AI Lens, 3D viewer, Hieroglyphics, Map…)
│   │   ├── services/             # PlacesRepo, ThreeDModelService, ChatSocketService
│   │   └── ai/                   # LandmarkClassifier, AILensService
│   └── assets/
│       ├── ml/                   # best_float32.tflite, labels.json (127 classes)
│       ├── html/                 # 3d_viewer.html (model-viewer WebView component)
│       └── icons/glyph_icons/    # 767 Gardiner sign PNGs bundled in APK
│
├── backend/                      # NestJS API Gateway
│   └── src/
│       ├── auth/                 # Firebase JWT AuthGuard (applied globally)
│       ├── profiles/             # User CRUD, S3 avatar upload/removal (IMDSv2)
│       ├── storytelling/         # Cache-first story retrieval + Groq generation
│       ├── recommendations/      # DayPlan / TripPlan + behavioral feedback
│       ├── agenda/               # CRUD with time-slot conflict detection
│       ├── favorites/            # Toggle add/remove landmark favorites
│       ├── discovery/            # Text search, 27 category filters, pagination
│       ├── places-map/           # Bulk lat/lng lookup for recommendation IDs
│       ├── hieroglyphics/        # JWT-guarded proxy to FastAPI (120 s timeout)
│       ├── 3dmodel/              # Full Modal pipeline: cache → S3 refs → GPU → poll
│       ├── chatbot/              # WebSocket gateway, FAISS RAG, Mistral streaming
│       └── database/             # Shared MySQL connection pool (TypeORM)
│
├── ai-service/
│   └── hieroglyphics-api/        # FastAPI AI service
│       ├── api/                  # 7 REST endpoints with Pydantic validation
│       ├── models/               # YOLOv8m detector, Transformer, ModelLoader singleton
│       ├── pipeline/             # Detection → Reading Order → Translation Orchestration
│       └── data/                 # translations_db.json, per-sign meanings database
│
├── modal-3d/                     # Hunyuan3D-2 serverless GPU application
│   └── app.py                    # Shape endpoint (sync) + Texture endpoint (async)
│
├── modal-chatbot/                # Mistral-7B serverless GPU application
│   └── app.py                    # Always-warm A10G, min_containers=1
│
├── training/
│   ├── ai-lens/                  # YOLOv8s training scripts, dataset YAML, export
│   ├── recommendation/           # Dual-tower training, synthetic data generation
│   └── hieroglyphics/            # YOLOv8m detector, Transformer, SentencePiece BPE
│
├── scripts/
│   ├── data/                     # TripAdvisor scraper, Google Maps Selenium scraper
│   └── seed/                     # landmarks.sql, ml_label fixes, bulk geocoding
│
├── docs/
│   ├── API.md                    # Full cURL + Node.js examples for all endpoints
│   ├── MODELS.md                 # Model weight download instructions
│   └── GANTT.pdf                 # Full project timeline
│
├── docker-compose.prod.yml       # Production: NestJS + FastAPI + MySQL on bridge network
├── nginx.conf                    # Reverse proxy config (port 80 → 3000 / 8000)
└── README.md
```

---

## Tech Stack

| Layer | Technology | Role |
|---|---|---|
| **Mobile** | Flutter 3.x (Dart) | Android application, on-device TFLite inference, WebView 3D viewer |
| **Backend** | NestJS 10 (Node.js 20 / TypeScript) | API gateway, 12 modules, WebSocket chatbot gateway |
| **AI Service** | FastAPI 0.110 (Python 3.11) | Hieroglyphics pipeline, lazy YOLOv8m loading |
| **Database** | MySQL 8.0 + TypeORM | 13 tables, relational schema, connection pooling |
| **Auth** | Firebase Authentication | JWT issuance + firebase-admin verification on every endpoint |
| **Storage** | AWS S3 (tourasna-assets) | Landmark photos, avatars, 3D refs, generated GLBs |
| **Inference — Chatbot** | Modal A10G + Mistral-7B | Always-warm, streams tokens to Flutter via WebSocket |
| **Inference — 3D** | Modal A100 + Hunyuan3D-2 | Shape + texture generation, persistent 27 GB weight volume |
| **LLM** | Groq API (LLaMA 3.3 70B) | Storytelling, hieroglyphic translation |
| **TTS** | Google TTS Chirp 3 HD | Neural audio narration, called directly from Flutter |
| **Maps** | Google Maps Flutter SDK | Map rendering, GPS, routing, proximity detection |
| **Proxy** | nginx | Port-80 routing, streaming (proxy_buffering off) |
| **Containers** | Docker + Docker Compose | 3 containers on private bridge network, 2 GB swap on EC2 |
| **Cloud** | AWS EC2 t3.small (eu-north-1) | 2 vCPU, 2 GB RAM, IP: 13.50.201.36 |

---

## Requirements

| Requirement | Version / Notes |
|---|---|
| Flutter | 3.x stable channel |
| Dart | Bundled with Flutter |
| Android SDK | API level 21+ |
| Node.js | 20 LTS |
| npm | 10+ |
| Python | 3.11 |
| Docker & Docker Compose | Any recent version |
| MySQL | 8.0 (or run via Docker) |
| Modal account | For GPU endpoints (3D + chatbot) |
| Groq API key | For storytelling + hieroglyphic translation |
| Firebase project | Authentication enabled, `google-services.json` downloaded |
| AWS account | EC2 IAM role with `AmazonS3FullAccess`, S3 bucket created |

> **Note:** An active internet connection is required for all AI-powered features. The only fully offline module is on-device YOLOv8s TFLite monument recognition.

---

## Installation

### Flutter Application

**Step 1 — Clone the repository:**
```bash
git clone https://github.com/Tourasna/Tourasna.git
cd Tourasna/flutter-app
```

**Step 2 — Install dependencies:**
```bash
flutter pub get
```

**Step 3 — Configure Firebase:**

Download `google-services.json` from the Firebase console and place it in `android/app/`. Verify the package name matches `applicationId` in `android/app/build.gradle`.

**Step 4 — Set the API base URL:**

Open `lib/core/network/api_client.dart` and set:
```dart
// Production
static const String baseUrl = 'http://13.50.201.36';

// Local emulator
static const String baseUrl = 'http://10.0.2.2:3000';
```

**Step 5 — Build and install:**
```bash
flutter build apk --release
flutter install
```

---

### NestJS Backend

**Step 1:**
```bash
cd Tourasna/backend
npm install
```

**Step 2 — Create environment file:**
```bash
cp .env.example .env
# Fill in all required values (see Environment Variables section)
```

**Step 3 — Run database migrations:**
```bash
npm run typeorm migration:run
```

**Step 4 — Start in production mode:**
```bash
npm run start:prod
```

---

### FastAPI AI Service

**Step 1:**
```bash
cd Tourasna/ai-service/hieroglyphics-api
python -m venv venv
source venv/bin/activate  # Linux/Mac
# or: venv\Scripts\activate  (Windows)
```

**Step 2:**
```bash
pip install -r requirements.txt
```

**Step 3 — Download model weights:**

Follow `docs/MODELS.md` to download the YOLOv8m detection checkpoint and Transformer translation weights from Google Drive into the `models/` directory.

**Step 4:**
```bash
uvicorn api.main:app --host 0.0.0.0 --port 8000
```

**Step 5 — Run tests:**
```bash
pytest -v  # 40 passing tests covering all endpoints and pipeline stages
```

Swagger documentation available at `http://localhost:8000/docs`.

---

### Docker Compose Deployment

**Step 1 — SSH into EC2 and clone:**
```bash
ssh -i your-key.pem ubuntu@13.50.201.36
git clone https://github.com/Tourasna/Tourasna.git && cd Tourasna
```

**Step 2 — Populate environment files:**
```bash
cp backend/.env.example backend/.env
# Edit with production values
```

**Step 3 — Build and start all containers:**
```bash
docker-compose -f docker-compose.prod.yml up -d --build
```

**Step 4 — Verify running containers:**
```bash
docker ps
# Expected: tourasna-backend (3000), tourasna-ai (8000), tourasna-mysql (3307) — all Up
```

**Step 5 — Configure and reload nginx:**
```bash
sudo nginx -t && sudo systemctl reload nginx
```

**Step 6 — Seed the database:**
```bash
docker exec -i tourasna-mysql mysql -u root -p tourasna < scripts/seed/landmarks.sql
```

---

### Modal GPU Endpoints

**Step 1 — Install Modal and authenticate:**
```bash
pip install modal
modal token new
```

**Step 2 — Deploy 3D generation endpoint (A100):**
```bash
cd Tourasna/modal-3d
modal deploy app.py
```

**Step 3 — Deploy chatbot endpoint (A10G):**
```bash
cd Tourasna/modal-chatbot
modal deploy app.py
```

**Step 4 — Update NestJS environment:**

Copy the deployed endpoint URLs from the Modal dashboard and set `MODAL_3D_ENDPOINT_URL` and `MODAL_CHATBOT_ENDPOINT_URL` in `backend/.env`.

> **Cold-start note:** The 3D endpoint may take 3–5 minutes to start from cold. The Flutter client handles this with a 14-retry polling loop (`COLD_RETRIES=14`, `COLD_WAIT_MS=30,000 ms`). The chatbot endpoint uses `min_containers=1` to stay always warm.

---

## Environment Variables

**`backend/.env`**

```env
# Database
DB_HOST=tourasna-mysql
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_mysql_password
DB_NAME=tourasna

# Firebase
FIREBASE_PROJECT_ID=your_firebase_project_id

# AWS
AWS_REGION=eu-north-1
S3_BUCKET_NAME=tourasna-assets

# External AI
GROQ_API_KEY=your_groq_api_key
MODAL_3D_ENDPOINT_URL=https://your-modal-3d-endpoint.modal.run
MODAL_CHATBOT_ENDPOINT_URL=https://your-modal-chatbot-endpoint.modal.run

# 3D pipeline tuning
COLD_RETRIES=14
COLD_WAIT_MS=30000
SHAPE_TIMEOUT_MS=120000
TEXTURE_POLL_INTERVAL=30000
TEXTURE_MAX_POLLS=100
```

**`ai-service/hieroglyphics-api/.env`**

```env
GROQ_API_KEY=your_groq_api_key
```

> **Security:** Never commit `.env` files. Add them to `.gitignore`. AWS credentials are sourced at runtime from the EC2 IAM role via IMDSv2 — no hardcoded keys anywhere in the codebase.

---

## API Reference

Base URL: `http://13.50.201.36/api` — All protected endpoints require `Authorization: Bearer <JWT>`.

| Method | Endpoint | Description |
|---|---|---|
| GET | `/storytelling/places` | 127 places with `hasStory` flag and photo URL |
| GET | `/storytelling/:placeId` | Cache-first story (EN + AR); generates via Groq on miss |
| GET | `/places-search/search` | Text search with `q`, `limit` params (27 category filters) |
| POST | `/recommendations` | DayPlan (10 landmarks) or TripPlan (5/day) ranked list |
| POST | `/recommendations/feedback` | Record like/dislike, update affinity, bust cache |
| POST | `/agenda` | Create item with time-slot conflict detection |
| GET | `/agenda` | Items for date range with lat/lng via JOIN |
| PUT | `/agenda/:id` | Update with conflict re-validation |
| DELETE | `/agenda/:id` | Remove agenda item |
| GET | `/favorites` | Saved landmarks with photos |
| POST | `/favorites/:id` | Add to favorites |
| DELETE | `/favorites/:id` | Remove from favorites |
| POST | `/places-map/landmark-locations` | Bulk name + lat/lng for landmark ID array |
| GET | `/profiles/me` | User profile |
| PUT | `/profiles/me` | Update profile fields |
| POST | `/profiles/avatar` | Multipart upload to S3 via IMDSv2 (max 5 MB) |
| DELETE | `/profiles/avatar` | AWS4-signed S3 delete + `avatar_url = NULL` |
| POST | `/hieroglyphics/translate` | Multipart image + direction → bilingual JSON (120 s timeout) |
| POST | `/3dmodel/generate` | Check cache or trigger full Modal pipeline |
| GET | `/3dmodel/status` | Status + GLB URLs; polled every 30 s by Flutter |
| WebSocket | `/chatbot` | JWT handshake → Mistral-7B token stream |

Full cURL and Node.js examples: `docs/API.md`

---

## Database Schema

| Table | Description |
|---|---|
| `profiles` | Firebase UID as PK; email, name, gender, nationality, preferences (JSON), budget, travel_type, avatar_url |
| `recommendation_items` | 677 Cairo/Giza landmarks — name, category, rating, lat/lng, photo_urls (JSON), budget_range, travel_types |
| `places` | 138 museum-level place records — ml_label (links to TFLite class name), bilingual info, photo_url, glb_url |
| `storytelling` | UNIQUE on (place_id, language) — story_en, story_ar; generated once, cached permanently |
| `agenda_items` | FK to profiles + recommendation_items; start/end datetime, time-conflict enforcement |
| `favorites` | Many-to-many between users and recommendation_items |
| `model_glbs` | UNIQUE on class_name; status ENUM (generating / shape_ready / textured / failed), GLB URLs, job ID |
| `recommendations_cache` | Per-user scored output; invalidated on every like/dislike feedback event |
| `user_interactions` | Like/dislike log — category, affinity_signal (+0.8 / −0.3), timestamp |
| `user_context` | Per-user budget, travel_type, interaction_count (updated after every feedback event) |
| `chat_sessions` | One row per chatbot session, FK to profiles |
| `chat_messages` | Individual messages within a session, FK to chat_sessions |

---

## AWS S3 Structure

Bucket: `tourasna-assets` (eu-north-1) — public-read policy, CORS enabled for all origins (required for WebView GLB fetching).

| S3 Path | Contents |
|---|---|
| `avatars/{uid}.jpg` | User avatars; max 5 MB; DELETE removes from S3 and sets `avatar_url = NULL` |
| `landmarks/places/{uuid}/photo_1.jpg` | Place photos (112 of 138 populated) |
| `models/refs/{NNN}_{ClassName}/top.jpg` | 3D reference views — 127 folders, front/side/back per class |
| `models/generated/shape_{uuid}.glb` | Shape-only GLBs (~20–45 s to generate) |
| `models/generated/textured_{uuid}.glb` | Fully textured GLBs (~10–20 min to generate) |

---

## AI Module Performance

| Module | Metric | Value |
|---|---|---|
| **Monument Recognition** | mAP50 (127 classes) | 0.904 |
| **Monument Recognition** | Classes in Excellent tier (≥ 0.85 mAP50) | 96 / 127 (75.6%) |
| **Recommendation Engine** | NDCG@5 | 0.9536 |
| **Recommendation Engine** | R² (continuous compatibility scoring) | 0.8020 |
| **FAHMY Chatbot** | Precision@5 | 0.83 |
| **FAHMY Chatbot** | Arabic BLEU | 0.71 |
| **3D Reconstruction** | Combined quality score | 17 / 24 (Good) |
| **3D Reconstruction** | Shape generation latency | 20–45 s |
| **3D Reconstruction** | Texture generation latency | 10–20 min (async) |
| **Hieroglyphics Detector** | Real-world mean confidence | 0.63–0.69 |
| **Hieroglyphics Translator** | Translation pipeline coverage | 100% (4-layer fallback) |

---

## Known Limitations

| Limitation | Detail |
|---|---|
| **Geographic scope** | Limited to Greater Cairo and Giza; other Egyptian governorates not covered |
| **Synthetic training data** | Recommendation engine trained on 5M synthetic interactions; real-world performance at scale is unvalidated |
| **Connectivity dependency** | All AI features (storytelling, chatbot, 3D generation, recommendations) require an active internet connection |
| **iOS support** | Flutter app targets Android only; iOS deployment deferred due to Apple Developer Programme requirements |
| **Texture generation latency** | Full textured 3D model takes 10–20 minutes; shape mesh is delivered progressively in the interim |
| **Hieroglyphics coverage** | YOLOv8m detection covers 767 Gardiner classes but performance degrades on damaged or densely clustered inscriptions |
| **Storytelling accuracy** | Narratives generated via general-purpose LLM without domain-specific Egyptological fine-tuning |
| **HTTP only** | Current deployment uses HTTP (port 80); HTTPS via nginx TLS required before Google Play Store submission |
| **No booking/payments** | Ticket booking, reservations, and payment processing are out of scope |

---

## Team

| Name | Student ID |
|---|---|
| Alia Mostafa | 221001994 |
| Fady Farouk | 221001641 |
| Hassan Sabry | 221001707 |
| Hossamaldeen Elghazaly | 221001672 |
| Moaz Elkhashab | 221001732 |
| Youssef Maged | 221001995 |

**Supervisors:** Dr. Noha Gamal Eldin · Dr. Mohamed ElHelw
**University:** Nile University — Faculty of Information Technology and Computer Science
**Course:** CSCI496: Senior Project II — Spring 2026

---

## License

MIT License — see [LICENSE](./LICENSE) for details.
