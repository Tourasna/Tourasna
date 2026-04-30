\# Models Setup Guide



> The trained ML models for the Tourasna Hieroglyphics Translator are \*\*not stored in this repository\*\* due to their size (\~200 MB total). This guide explains how to download and place them correctly.



\---



\## 📦 Required Models



The API needs \*\*two models\*\* to function:



| Model        | File                              | Size    | Purpose                              |

|--------------|-----------------------------------|---------|--------------------------------------|

| Detector v2  | `best.pt`                         | \~150 MB | YOLOv8m - detect \& classify glyphs   |

| Translator   | `best\_translator.pth`             | \~46 MB  | Seq2Seq Transformer for translation  |

| Vocab files  | `src\_vocab.json`, `tgt\_bpe.model`, `metadata.json` | \~500 KB | Tokenizers + model metadata |



\---



\## 📁 Expected Directory Structure



After downloading, your `models/` folder must look like this:

models/

├── detector/

│   └── best.pt                    ← Detector weights (YOLOv8m)

└── translator/

├── best\_translator.pth        ← Translator weights

├── src\_vocab.json             ← Source vocab (Gardiner codes)

├── tgt\_bpe.model              ← Target BPE tokenizer

└── metadata.json              ← Model architecture info



The API will fail to start if any of these files are missing.



\---



\## ⬇️ Download Instructions



\### Option 1: Google Drive (Recommended)



The models are hosted on the Tourasna team's Google Drive:

📂 Tourasna/hieroglyphics/

├── detector\_v2/final\_Training\_detector\_v2/

│   └── best.pt

└── translator/

├── best\_translator.pth

├── src\_vocab.json

├── tgt\_bpe.model

└── metadata.json



\*\*Manual download steps:\*\*



1\. Request access to the Tourasna Google Drive folder from the project owner

2\. Navigate to `Tourasna/hieroglyphics/`

3\. Download the files listed above

4\. Place them into your local `models/` folder following the structure above



\### Option 2: Direct Links (Internal Team Only)



> ⚠️ These links require team-member permissions. Reach out to the project lead for access.



\- Detector: `https://drive.google.com/file/d/<DETECTOR\_FILE\_ID>/view`

\- Translator weights: `https://drive.google.com/file/d/<TRANSLATOR\_WEIGHTS\_ID>/view`

\- Source vocab: `https://drive.google.com/file/d/<SRC\_VOCAB\_ID>/view`

\- Target BPE: `https://drive.google.com/file/d/<TGT\_BPE\_ID>/view`

\- Metadata: `https://drive.google.com/file/d/<METADATA\_ID>/view`



> 📝 \*\*Note for team:\*\* Replace `<...>` placeholders with actual Google Drive file IDs before sharing this document externally.



\---



\## ✅ Verifying Your Setup



After placing all files, verify the structure with:



\### Windows (cmd)

```cmd

dir /S models

```



\### Linux / macOS

```bash

ls -lR models/

```



You should see all 5 files in the correct subdirectories.



\### Quick startup test



```bash

python -c "from api.services.model\_loader import loader; loader.load\_all(); print('All models loaded successfully!')"

```



If everything is correct, you'll see logs like:

INFO Loading translations database from: data/translations\_db.json

INFO Loading YOLO detector from: models/detector/best.pt

INFO Detector loaded in 0.14s (767 classes, device=cpu)

INFO Loading Transformer translator...

INFO Translator loaded in 0.16s (11,819,072 params, src\_vocab=1333, tgt\_vocab=8000)

INFO Pipeline loaded successfully. API is ready.

All models loaded successfully!



\---



\## 🏗️ Model Specifications



\### Detector v2 (YOLOv8m)



| Property            | Value                                |

|---------------------|--------------------------------------|

| Architecture        | YOLOv8m (medium variant)             |

| Classes             | 767 Gardiner codes                   |

| Training images     | 32,000+                              |

| Best epoch          | 40 / 50                              |

| Validation mAP@50   | 0.0192                               |

| Validation mAP@50-95| 0.0181                               |

| Real-world accuracy | Mean confidence 0.63–0.69 on tourist photos |

| Training infra      | Kaggle (T4 GPU)                      |

| Input size          | 640 × 640 px                         |



> \*\*Why is mAP low?\*\* Hieroglyphic detection has 767 classes — many extremely rare or visually similar. The validation metric is harsh because a "near-miss" (e.g., predicting M16 instead of M17) is counted as a complete miss. On real tourist photos the detector performs much better than mAP suggests.



\### Translator (Custom Seq2Seq Transformer)



| Property         | Value                              |

|------------------|------------------------------------|

| Architecture     | Transformer Encoder-Decoder (PyTorch) |

| Parameters       | 11,819,072 (\~11.8 M)               |

| Source vocab     | 1,333 tokens (Gardiner codes)      |

| Target vocab     | 8,000 tokens (BPE-encoded English) |

| Training corpus  | BBAW (\~100K parallel sentences)    |

| BLEU score       | 7.76 (validation)                  |

| Decoding         | Beam search (beam=5, length-norm)  |

| Repetition penalty | 1.2                              |



> \*\*About BLEU 7.76:\*\* Egyptian-to-English is one of the hardest translation tasks in NLP — even research-grade models top out around BLEU 21. Our 7.76 is a reasonable baseline, used as \*\*Layer 3 fallback\*\* behind the curated database (Layer 1) and the LLM (Layer 2).



\---



\## 🔧 Customization



If you train your own models or update the existing ones, update these settings in `.env`:



```ini

\# Override the model paths if needed (defaults are usually fine)

\# DETECTOR\_WEIGHTS=models/detector/best.pt

\# TRANSLATOR\_WEIGHTS=models/translator/best\_translator.pth

```



The defaults in `api/config.py` should work for the standard directory layout.



\---



\## ❓ Troubleshooting



\### `FileNotFoundError: models/detector/best.pt`



The detector weights are missing. Check:

1\. The file is exactly named `best.pt` (case-sensitive on Linux)

2\. It's inside `models/detector/`, not directly in `models/`

3\. The file isn't 0 bytes (sometimes Drive downloads fail silently)



\### `RuntimeError: Error(s) in loading state\_dict`



The translator weights don't match the expected architecture. Solutions:

1\. Make sure you downloaded `best\_translator.pth` (not an older version)

2\. Check that `metadata.json` is present and correct

3\. The architecture is defined in `api/services/transformer\_model.py` — keep it synced with whatever the weights were trained on



\### Models load but predictions are wrong



1\. Check that `src\_vocab.json` has at least 1,300 entries

2\. Check that `tgt\_bpe.model` is the SentencePiece BPE model used during training

3\. Verify the model files match by comparing file sizes against the Drive originals



\### `CUDA out of memory`



The default device is `auto`. Force CPU mode in `.env`:

```ini

DEVICE=cpu

```



CPU is slower but works on any machine. Detection on a 750×500 image takes \~2 seconds on CPU vs <0.5s on GPU.



\---



\## 📜 Model Provenance



| Component           | Trained By           | Data Source                                                      |

|---------------------|----------------------|------------------------------------------------------------------|

| Detector v2         | Tourasna team (2026) | Kaggle dataset by Mohiey Mohamed (mohieyelkiouty)                |

| Translator          | Tourasna team (2026) | BBAW Egyptian Corpus (huggingface.co/datasets/phiwi/bbaw\_egyptian) |

| Translations DB     | Tourasna team (2026) | Curated by team — historical references + GEM museum inscriptions |

| Sign meanings       | Tourasna team (2026) | Gardiner Sign List + Egyptological references                    |



\---



\## 🚫 Do NOT Commit Models to Git



The `.gitignore` already excludes the `models/` directory. \*\*Do not bypass this\*\* — large binary files don't belong in Git, and we'd hit GitHub's 100 MB file limit.



If you need to share updated models with the team:

1\. Upload to the team's Google Drive

2\. Update the links in this document

3\. Notify the team in your standup / chat

