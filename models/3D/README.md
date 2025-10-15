
# 🏛️ Tourasna 3D Models Integration

This repository contains links to 3D `.glb` models stored on Firebase/Google Cloud Storage.  
The models represent Egyptian heritage and tourist sites, ready to be integrated into the **Tourasna Flutter app**.

---

## 📂 Storage Overview

- **Bucket name:** `tourasna-storage`  
- **Access:** Public (read-only)  
- **Folder:** `3d_models/`

Each model can be loaded directly using its public URL.

---

## 🌐 Example `.glb` URLs (3 of 30 total)

| # | Model Name | Public URL |
|---|-------------|------------|
| 1 | Aisha Fahmy Palace | [View Model](https://storage.googleapis.com/tourasna-storage/3d_models/Aisha%20Fahmy%20Palace.glb) |
| 2 | Al-Azhar Mosque | [View Model](https://storage.googleapis.com/tourasna-storage/3d_models/Al-Azhar%20Mosque.glb) |
| 3 | Amr Ibn Al-Aas Mosque | [View Model](https://storage.googleapis.com/tourasna-storage/3d_models/Amr%20Ibn%20Al-Aas%20Mosque.glb) |

*(These are 3 examples out of 30 total uploaded models.)*

---

## 🧩 Flutter Integration Example

You can use the [`model_viewer`](https://pub.dev/packages/model_viewer) Flutter package to display the `.glb` files:

```dart
import 'package:model_viewer_plus/model_viewer_plus.dart';

ModelViewer(
  src: 'https://storage.googleapis.com/tourasna-storage/3d_models/Aisha%20Fahmy%20Palace.glb',
  alt: 'Aisha Fahmy Palace 3D Model',
  ar: true,
  autoRotate: true,
  cameraControls: true,
);
```

---

## 🔐 Access Policy

- All `.glb` files are **publicly readable**, so the Flutter app can fetch them directly.  
- Only project maintainers can **upload or modify** files in the bucket.  
- For security, write access is limited to the Firebase service account.

---

## 🧾 Notes

- Each 3D model follows the `.glb` (binary glTF) standard.  
- Ensure your Flutter app has internet permission enabled.  
- For offline caching or optimization, consider downloading and bundling critical assets.

---

**Maintainer:** Tourasna 3D Team  
**Firebase Bucket:** `tourasna-storage`  
**Total Models:** 30
