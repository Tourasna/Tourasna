\# API Reference



> Complete reference for the Tourasna Hieroglyphics Translator API.



\*\*Base URL:\*\* `http://localhost:8000` (development)



\*\*Content-Type:\*\* `application/json` (except `/translate` which uses `multipart/form-data`)



\---



\## Table of Contents



1\. \[Health Check](#health-check)

2\. \[Translate Image](#translate-image-full-pipeline)

3\. \[Translate Codes](#translate-codes-direct-translation)

4\. \[Translate Corrected](#translate-corrected-human-in-the-loop)

5\. \[List Signs](#list-signs)

6\. \[Sign Info](#sign-info)

7\. \[Search Signs](#search-signs)

8\. \[Error Responses](#error-responses)

9\. \[Translation Methods](#translation-methods)



\---



\## Health Check



Check that the API is running and all models are loaded.



\### `GET /api/health`



\*\*Response 200 OK:\*\*

```json

{

&#x20; "status": "healthy",

&#x20; "version": "1.0.0",

&#x20; "device": "cpu",

&#x20; "models\_loaded": true,

&#x20; "uptime\_seconds": 142.7

}

```



\---



\## Translate Image (Full Pipeline)



Run the full pipeline: detect glyphs from an image, sort them by reading order, and translate.



\### `POST /api/translate`



\*\*Request:\*\* `multipart/form-data`



| Field               | Type   | Required | Description                                    |

|---------------------|--------|----------|------------------------------------------------|

| `image`             | file   | Yes      | Image file (JPEG/PNG/WEBP, max 10 MB)         |

| `reading\_direction` | string | No       | `rtl`, `ltr`, or `ttb` (default: `rtl`)        |



\*\*Example Request (cURL):\*\*

```bash

curl -X POST http://localhost:8000/api/translate \\

&#x20; -F "image=@cartouche.jpg" \\

&#x20; -F "reading\_direction=rtl"

```



\*\*Example Request (NodeJS + axios):\*\*

```javascript

const FormData = require('form-data');

const fs = require('fs');

const axios = require('axios');



const form = new FormData();

form.append('image', fs.createReadStream('cartouche.jpg'));

form.append('reading\_direction', 'rtl');



const response = await axios.post(

&#x20; 'http://localhost:8000/api/translate',

&#x20; form,

&#x20; { headers: form.getHeaders() }

);



console.log(response.data);

```



\*\*Response 200 OK:\*\*

```json

{

&#x20; "image\_size": { "width": 748, "height": 419 },

&#x20; "reading\_direction": "rtl",

&#x20; "total\_detections": 5,

&#x20; "rows": 1,

&#x20; "quadrats": 5,

&#x20; "detections": \[

&#x20;   {

&#x20;     "id": 1,

&#x20;     "gardiner\_code": "N5",

&#x20;     "confidence": 0.95,

&#x20;     "bounding\_box": { "x1": 100, "y1": 50, "x2": 180, "y2": 130 },

&#x20;     "row": 1,

&#x20;     "quadrat\_id": 1,

&#x20;     "position\_in\_quadrat": 1,

&#x20;     "alternatives": \[]

&#x20;   }

&#x20; ],

&#x20; "gardiner\_sequence": \["N5", "S29", "S29", "M23", "X1"],

&#x20; "translation": {

&#x20;   "method": "database\_exact",

&#x20;   "translation\_en": "Ramesses — Born of Ra",

&#x20;   "translation\_ar": "رمسيس — ابن رع",

&#x20;   "transliteration": "Ra-mes-su",

&#x20;   "context\_en": "Birth name of Ramesses II, one of Egypt's greatest pharaohs...",

&#x20;   "context\_ar": "اسم الميلاد لرمسيس الثاني...",

&#x20;   "sign\_details": \[

&#x20;     {

&#x20;       "code": "N5",

&#x20;       "meaning\_en": "sun disk (Ra)",

&#x20;       "meaning\_ar": "قرص الشمس (رع)",

&#x20;       "sound": "Ra",

&#x20;       "category": "sky"

&#x20;     }

&#x20;   ]

&#x20; }

}

```



\*\*Notes on `alternatives`:\*\*

\- An empty array means the detector was confident.

\- A non-empty array (max 3 items) means the detection is \*ambiguous\* — the user should be shown the alternatives to choose from. See \[`/api/translate-corrected`](#translate-corrected-human-in-the-loop).



\---



\## Translate Codes (Direct Translation)



Skip the image pipeline and translate a known sequence of Gardiner codes. Useful for testing or when codes come from another source.



\### `POST /api/translate-codes`



\*\*Request Body:\*\*

```json

{

&#x20; "gardiner\_codes": \["N5", "S29", "S29", "M23", "X1"],

&#x20; "reading\_direction": "rtl"

}

```



\*\*Response 200 OK:\*\* Same `translation` object as `/api/translate`, plus:

```json

{

&#x20; "gardiner\_codes": \["N5", "S29", "S29", "M23", "X1"],

&#x20; "reading\_direction": "rtl",

&#x20; "translation": { ... }

}

```



\---



\## Translate Corrected (Human-in-the-Loop)



After the user reviews detections in the app and corrects/confirms the sequence, send the final list here. This endpoint trusts the input as ground truth.



\### `POST /api/translate-corrected`



\*\*Request Body:\*\*

```json

{

&#x20; "corrected\_sequence": \["M17", "M17", "X1", "N29", "S34", "Y1", "M17", "M17", "N35"],

&#x20; "reading\_direction": "rtl"

}

```



\*\*Response 200 OK:\*\*

```json

{

&#x20; "corrected\_sequence": \["M17", "M17", "X1", "N29", "S34", "Y1", "M17", "M17", "N35"],

&#x20; "reading\_direction": "rtl",

&#x20; "translation": {

&#x20;   "method": "database\_exact",

&#x20;   "translation\_en": "Tutankhamun — Living Image of Amun",

&#x20;   "translation\_ar": "توت عنخ آمون — صورة آمون الحية",

&#x20;   ...

&#x20; }

}

```



\---



\## List Signs



Returns all 64 known Gardiner signs with their meanings.



\### `GET /api/signs`



\*\*Response 200 OK:\*\*

```json

{

&#x20; "total": 64,

&#x20; "signs": \[

&#x20;   {

&#x20;     "code": "N5",

&#x20;     "meaning\_en": "sun disk (Ra)",

&#x20;     "meaning\_ar": "قرص الشمس (رع)",

&#x20;     "sound": "Ra",

&#x20;     "category": "sky"

&#x20;   }

&#x20; ]

}

```



\---



\## Sign Info



Get detailed info for a specific Gardiner sign — useful for the correction UI's "info" tooltip.



\### `GET /api/sign/{code}/info`



\*\*Path parameters:\*\*

| Param | Type   | Description                  |

|-------|--------|------------------------------|

| code  | string | Gardiner code (e.g., `N5`)   |



\*\*Response 200 OK:\*\*

```json

{

&#x20; "code": "N5",

&#x20; "name\_en": "sun disk",

&#x20; "name\_ar": "قرص الشمس",

&#x20; "transliteration": "ra",

&#x20; "category": "sky",

&#x20; "common\_confusions": \["N6", "N9"],

&#x20; "examples": \["Used in royal names like Ramesses (N5+S29+S29+M23+X1)"],

&#x20; "meaning\_notes": "Symbol of the sun god Ra. Often appears in royal cartouches."

}

```



\*\*Response 404 Not Found:\*\*

```json

{

&#x20; "detail": "Sign 'XYZ' not found"

}

```



\---



\## Search Signs



Search for signs by code, English name, Arabic name, or transliteration. Useful for the "Add Glyph" feature in the correction UI.



\### `GET /api/signs/search`



\*\*Query parameters:\*\*

| Param | Type    | Required | Description                       |

|-------|---------|----------|-----------------------------------|

| q     | string  | Yes      | Search query                      |

| limit | integer | No       | Max results (default: 10)         |



\*\*Example:\*\* `GET /api/signs/search?q=mouth\&limit=5`



\*\*Response 200 OK:\*\*

```json

{

&#x20; "query": "mouth",

&#x20; "total": 1,

&#x20; "results": \[

&#x20;   {

&#x20;     "code": "D21",

&#x20;     "name\_en": "mouth",

&#x20;     "name\_ar": "فم",

&#x20;     "transliteration": "r",

&#x20;     "score": 1.0

&#x20;   }

&#x20; ]

}

```



`score` is the relevance match (0.0 to 1.0). Results are sorted by score descending.



\---



\## Error Responses



\### 422 Validation Error

Returned when the request body fails Pydantic validation.



```json

{

&#x20; "error": "validation\_error",

&#x20; "message": "Request body or parameters failed validation.",

&#x20; "details": {

&#x20;   "errors": \[

&#x20;     {

&#x20;       "type": "missing",

&#x20;       "loc": \["body", "gardiner\_codes"],

&#x20;       "msg": "Field required",

&#x20;       "input": {}

&#x20;     }

&#x20;   ]

&#x20; }

}

```



\### 400 Bad Request

Returned for invalid image uploads, oversized files, or unsupported content types.



```json

{

&#x20; "error": "bad\_request",

&#x20; "message": "Image too large (12.3 MB). Max allowed is 10 MB."

}

```



\### 500 Internal Server Error

Returned when the pipeline encounters an unexpected error.



```json

{

&#x20; "error": "internal\_error",

&#x20; "message": "An unexpected error occurred. Please try again."

}

```



\---



\## Translation Methods



The `translation.method` field tells you which layer of the hybrid translator produced the result. The frontend can use this to display a confidence indicator or method badge.



| Method              | Layer | Description                                                                   |

|---------------------|-------|-------------------------------------------------------------------------------|

| `database\_exact`    | 1     | Matched a curated phrase in the database. Highest accuracy. Instant (<100ms). |

| `llm\_translation`   | 2     | Translated by Groq + Llama 3.3 70B. Grammatical, bilingual. \~1-3 seconds.     |

| `transformer`       | 3     | Translated by our trained Seq2Seq Transformer (BLEU 7.76). Offline fallback.  |

| `sign\_meanings`     | 4     | Per-sign concatenation. Always succeeds. Useful as a last resort.             |

| `empty`             | -     | No glyphs detected in the image.                                              |



\*\*Recommendation for frontend:\*\* Display a small badge next to the translation to indicate confidence:

\- 🟢 Database (highest confidence)

\- 🔵 LLM (high confidence)

\- 🟡 Transformer (medium confidence)

\- ⚪ Sign meanings (low confidence — show with caveat)



\---



\## Reading Directions



Hieroglyphic inscriptions can be written in three directions. The user (or your app) should specify which to use:



| Value | Direction       | When to Use                                     |

|-------|-----------------|-------------------------------------------------|

| `rtl` | Right-to-Left   | Most common (cartouches, monumental texts)      |

| `ltr` | Left-to-Right   | Some inscriptions, especially later periods     |

| `ttb` | Top-to-Bottom   | Vertical columns (common in temple walls)       |



\*\*Hint for users:\*\* Look at the direction the human/animal figures are \*facing\* — the inscription is read \*toward\* them. This rule isn't 100% reliable; let the user toggle.



\---



\## Rate Limits



The API does not enforce rate limits internally. \*\*The NodeJS backend should implement rate limiting\*\* to protect:

\- The Groq API quota (free tier: 30 req/min, 14,400/day)

\- Server resources (image processing is CPU-intensive)



Recommended limits per user:

\- `/api/translate`: 10 requests/minute

\- `/api/translate-codes`, `/api/translate-corrected`: 30 requests/minute

\- Reference endpoints (`/signs`, `/sign/\*/info`, `/signs/search`): 60 requests/minute



