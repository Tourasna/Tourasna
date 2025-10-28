# 🏛️ Tourasna 3D & ML Integration

This repository contains two main components used in the **Tourasna Flutter application**:

1. 🧩 **3D `.glb` models** of Egyptian heritage sites (stored on Firebase/Google Cloud Storage).  
2. 🧠 **Machine Learning model (`.tflite`)** for Egyptian landmark image classification.

Both components work together to enhance the Tourasna experience — allowing users to explore Egypt’s landmarks in 3D and identify them automatically through AI.

---

## 📦 Repository Contents

| Folder / File | Description |
|----------------|-------------|
| `/3d_models/` | Contains URLs for `.glb` models hosted on Firebase |
| `/ml_model/landmark_classifier.tflite` | TensorFlow Lite model used for image classification |
| `/ml_model/label_map.json` | Label mapping for landmark names |
| `/docs/` | Additional resources and project documentation |

---

## 🌐 3D Models Overview

- **Bucket name:** `tourasna-storage`  
- **Access:** Public (read-only)  
- **Folder:** `3d_models/`

Each `.glb` model represents a famous Egyptian heritage site.

### Example Public URLs (3 of 30 total)

| # | Model Name | Public URL |
|---|-------------|------------|
| 1 | Aisha Fahmy Palace | [View Model](https://storage.googleapis.com/tourasna-storage/3d_models/Aisha%20Fahmy%20Palace.glb) |
| 2 | Al-Azhar Mosque | [View Model](https://storage.googleapis.com/tourasna-storage/3d_models/Al-Azhar%20Mosque.glb) |
| 3 | Amr Ibn Al-Aas Mosque | [View Model](https://storage.googleapis.com/tourasna-storage/3d_models/Amr%20Ibn%20Al-Aas%20Mosque.glb) |

*(These are 3 examples out of 30 total uploaded models.)*

---

## 🧠 Landmark Classification Model (ML Integration)

The **`landmark_classifier.tflite`** model is a pre-trained TensorFlow Lite model capable of recognizing Egyptian tourist landmarks from images.

### Model Files
| File | Purpose |
|-------|----------|
| `landmark_classifier.tflite` | Lightweight ML model for on-device inference |
| `label_map (1).json` | List of landmark names (used for readable predictions) |

---

## ⚙️ Flutter Integration Guide (for the Flutter Team)

### 1️⃣ Add dependencies
In `pubspec.yaml`:
```yaml
dependencies:
  tflite_flutter: ^0.10.1
  image: ^4.2.2
  model_viewer_plus: ^1.7.1
