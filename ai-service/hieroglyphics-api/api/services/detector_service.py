"""
Detector service — wraps the YOLOv8 model with a clean interface.

Responsible for:
  - Accepting an image (PIL Image, numpy array, or bytes)
  - Running YOLO detection + classification
  - Filtering by the configured confidence threshold
  - Marking low-confidence detections as ambiguous
  - Extracting top-K alternative classifications for each detection
  - Returning a list of RawDetection schemas (no reading order yet)

Top-K alternatives are extracted by using Ultralytics' non_max_suppression
with return_idxs=True, which gives us the anchor index each surviving
detection came from. We then read that anchor's full class probability
vector from the raw model output to extract runner-up classes.

The reading order (row, quadrat, position) is filled in by the
SorterService in the next step.
"""
from __future__ import annotations

import io
from typing import Union

import numpy as np
import torch
from loguru import logger
from PIL import Image
from ultralytics.utils.ops import non_max_suppression

from api.config import settings
from api.schemas import Alternative, BoundingBox, RawDetection
from api.services.model_loader import ModelLoader


# Type alias for the inputs we accept
ImageInput = Union[Image.Image, np.ndarray, bytes]

# YOLO was trained at 640x640. The letterbox keeps aspect ratio.
YOLO_INPUT_SIZE = 640


class DetectorService:
    """
    YOLO-based hieroglyph detector service with top-K alternatives support.

    Usage:
        detector = DetectorService(loader)
        detections = detector.detect(pil_image)
    """

    def __init__(self, loader: ModelLoader) -> None:
        if not loader.is_loaded:
            raise RuntimeError(
                "ModelLoader is not loaded. Call loader.load_all() before "
                "instantiating services."
            )
        self.loader = loader

    def detect(self, image: ImageInput) -> list[RawDetection]:
        """
        Run detection + classification on the given image.

        Args:
            image: PIL Image, numpy array (BGR, OpenCV-style), or image bytes.

        Returns:
            List of RawDetection objects in YOLO's output order.
            Reading order is applied later by the SorterService.
        """
        pil_image = self._prepare_image(image)
        orig_w, orig_h = pil_image.size
        logger.debug(
            f"Running detection on image: size=({orig_w}, {orig_h}), "
            f"mode={pil_image.mode}"
        )

        # Preprocess: letterbox to 640x640, normalize, CHW tensor
        tensor, scale, pad_x, pad_y = self._preprocess(pil_image)

        # Forward pass on the underlying torch model.
        # preds shape: (1, 4 + num_classes, num_anchors)
        inner = self.loader.yolo_model.model
        inner.eval()
        with torch.no_grad():
            raw_output = inner(tensor)

        preds = raw_output[0] if isinstance(raw_output, (tuple, list)) else raw_output

        # Extract per-anchor class scores for top-K lookup.
        # preds[0, 4:, :] shape: (num_classes, num_anchors)
        # For YOLOv8, these are already sigmoid-activated probabilities.
        class_scores = preds[0, 4:, :]  # (num_classes, num_anchors)
        num_classes = class_scores.shape[0]

        # Run NMS. With nc=num_classes, it treats everything past index 4
        # as class scores and picks the top class per anchor. The key trick:
        # we ask it to also return the index of each anchor it kept.
        # API: non_max_suppression returns a list-of-tensors (one per image).
        # Each tensor is (N, 6) by default: [x1, y1, x2, y2, conf, cls].
        # Passing return_idxs=True makes it return a tuple of (outputs, keep_idxs).
        try:
            nms_result, keep_idxs = non_max_suppression(
                preds,
                conf_thres=settings.detector_conf_threshold,
                iou_thres=settings.detector_iou_threshold,
                max_det=settings.detector_max_detections,
                return_idxs=True,
            )
        except TypeError:
            # Older Ultralytics versions don't have return_idxs. Fall back:
            # we'll match anchors by class_id + confidence equality below.
            nms_result = non_max_suppression(
                preds,
                conf_thres=settings.detector_conf_threshold,
                iou_thres=settings.detector_iou_threshold,
                max_det=settings.detector_max_detections,
            )
            keep_idxs = None

        nms_out = nms_result[0]
        kept_anchor_idxs = keep_idxs[0] if keep_idxs is not None else None

        if nms_out is None or nms_out.shape[0] == 0:
            logger.info("No glyphs detected in image")
            return []

        # Fallback anchor matching if return_idxs is unavailable.
        # We identify each detection's anchor by matching (class_id, conf)
        # against the raw class_scores tensor. This works because NMS keeps
        # the exact conf value of the anchor.
        if kept_anchor_idxs is None:
            kept_anchor_idxs = self._match_anchors_by_conf(nms_out, class_scores)

        return self._build_detections(
            nms_out=nms_out,
            kept_anchor_idxs=kept_anchor_idxs,
            class_scores=class_scores,
            orig_w=orig_w,
            orig_h=orig_h,
            scale=scale,
            pad_x=pad_x,
            pad_y=pad_y,
        )

    # -------------------------------------------------------------------------
    # Preprocessing
    # -------------------------------------------------------------------------

    @staticmethod
    def _prepare_image(image: ImageInput) -> Image.Image:
        """Convert any supported input into a RGB PIL.Image."""
        if isinstance(image, Image.Image):
            pil = image
        elif isinstance(image, np.ndarray):
            if image.ndim == 3 and image.shape[2] == 3:
                pil = Image.fromarray(image[..., ::-1])
            elif image.ndim == 2:
                pil = Image.fromarray(image)
            else:
                raise ValueError(
                    f"Unsupported numpy image shape: {image.shape}. "
                    f"Expected (H, W) or (H, W, 3)."
                )
        elif isinstance(image, (bytes, bytearray)):
            try:
                pil = Image.open(io.BytesIO(image))
                pil.load()
            except Exception as exc:
                raise ValueError(f"Could not decode image bytes: {exc}") from exc
        else:
            raise TypeError(
                f"Unsupported image type: {type(image).__name__}. "
                f"Expected PIL.Image, numpy.ndarray, or bytes."
            )

        if pil.mode != "RGB":
            pil = pil.convert("RGB")

        if pil.width < 10 or pil.height < 10:
            raise ValueError(
                f"Image is too small: {pil.size}. Minimum 10x10 required."
            )

        return pil

    def _preprocess(
        self, pil_image: Image.Image
    ) -> tuple[torch.Tensor, float, float, float]:
        """Letterbox resize + normalize to (1, 3, 640, 640) float tensor."""
        orig_w, orig_h = pil_image.size
        scale = min(YOLO_INPUT_SIZE / orig_w, YOLO_INPUT_SIZE / orig_h)
        new_w, new_h = int(round(orig_w * scale)), int(round(orig_h * scale))

        resized = pil_image.resize((new_w, new_h), Image.BILINEAR)

        padded = Image.new("RGB", (YOLO_INPUT_SIZE, YOLO_INPUT_SIZE), (114, 114, 114))
        pad_x = (YOLO_INPUT_SIZE - new_w) // 2
        pad_y = (YOLO_INPUT_SIZE - new_h) // 2
        padded.paste(resized, (pad_x, pad_y))

        arr = np.asarray(padded, dtype=np.float32) / 255.0
        tensor = torch.from_numpy(arr).permute(2, 0, 1).unsqueeze(0)
        tensor = tensor.to(self.loader.device)

        return tensor, scale, float(pad_x), float(pad_y)

    # -------------------------------------------------------------------------
    # Anchor matching (fallback for old Ultralytics)
    # -------------------------------------------------------------------------

    @staticmethod
    def _match_anchors_by_conf(
        nms_out: torch.Tensor, class_scores: torch.Tensor
    ) -> torch.Tensor:
        """
        For each detection in nms_out, find the anchor whose class probability
        for the detected class matches the NMS confidence field.

        Used only when Ultralytics doesn't expose return_idxs directly.
        """
        anchor_idxs = []
        for row in nms_out:
            conf = row[4]
            class_id = int(row[5])
            # class_scores[class_id, :] has shape (num_anchors,).
            # Find the anchor whose value equals the NMS conf.
            class_row = class_scores[class_id]
            diffs = (class_row - conf).abs()
            anchor_idx = int(diffs.argmin().item())
            anchor_idxs.append(anchor_idx)
        return torch.tensor(anchor_idxs, dtype=torch.long)

    # -------------------------------------------------------------------------
    # Detection construction + top-K alternatives
    # -------------------------------------------------------------------------

    def _build_detections(
        self,
        nms_out: torch.Tensor,
        kept_anchor_idxs: torch.Tensor,
        class_scores: torch.Tensor,
        orig_w: int,
        orig_h: int,
        scale: float,
        pad_x: float,
        pad_y: float,
    ) -> list[RawDetection]:
        """
        Convert NMS output into RawDetection objects with top-K alternatives.

        nms_out: (N, 6) [x1, y1, x2, y2, conf, class_id] in letterboxed coords
        kept_anchor_idxs: (N,) anchor index for each detection
        class_scores: (num_classes, num_anchors) per-anchor probabilities
        scale, pad_x, pad_y: letterbox transform parameters
        """
        num_classes = class_scores.shape[0]
        top_k = settings.ambiguity_top_k
        ambiguity_thres = settings.ambiguity_threshold
        # A generous floor for what counts as a viable alternative: if the
        # top-1 is "sun", a 1% chance of "moon" probably isn't useful to show.
        # We keep alternatives at >= 10% of the main prediction's confidence.
        alt_rel_floor = 0.10

        detections: list[RawDetection] = []
        unknown_class_count = 0

        for i in range(nms_out.shape[0]):
            row = nms_out[i]
            x1_lb, y1_lb, x2_lb, y2_lb = (float(v) for v in row[:4])
            conf = float(row[4])
            class_id = int(row[5])

            code = self.loader.gardiner_class_names.get(class_id)
            if code is None:
                unknown_class_count += 1
                continue

            # -------- Extract top-K classes for this detection's anchor ------
            anchor_idx = int(kept_anchor_idxs[i].item())
            anchor_probs = class_scores[:, anchor_idx]  # (num_classes,)

            # Ask for K+1 because the top-1 is the main prediction (we skip it).
            k_lookup = min(top_k + 1, num_classes)
            top = torch.topk(anchor_probs, k=k_lookup)

            # Dynamic floor: only alternatives with conf >= 10% of top-1 conf.
            # For a top-1 of 0.42, the floor is 0.042 — low enough to surface
            # plausible runner-ups, high enough to reject the long tail.
            abs_floor = conf * alt_rel_floor

            alternatives: list[Alternative] = []
            for rank in range(k_lookup):
                alt_class_id = int(top.indices[rank].item())
                alt_conf = float(top.values[rank].item())
                if alt_class_id == class_id:
                    continue  # this is the main prediction
                if alt_conf < abs_floor:
                    break  # sorted descending, so the rest are lower too
                alt_code = self.loader.gardiner_class_names.get(alt_class_id)
                if alt_code is None:
                    continue
                alternatives.append(
                    Alternative(gardiner_code=alt_code, confidence=alt_conf)
                )
                if len(alternatives) >= top_k:
                    break

            # -------- Undo letterbox to get original-image coordinates -------
            x1 = (x1_lb - pad_x) / scale
            y1 = (y1_lb - pad_y) / scale
            x2 = (x2_lb - pad_x) / scale
            y2 = (y2_lb - pad_y) / scale

            x1 = max(0.0, min(float(orig_w), x1))
            y1 = max(0.0, min(float(orig_h), y1))
            x2 = max(0.0, min(float(orig_w), x2))
            y2 = max(0.0, min(float(orig_h), y2))

            if x2 <= x1 or y2 <= y1:
                continue

            bbox = BoundingBox(x1=x1, y1=y1, x2=x2, y2=y2)
            is_ambiguous = conf < ambiguity_thres

            detections.append(
                RawDetection(
                    gardiner_code=code,
                    confidence=conf,
                    bbox=bbox,
                    is_ambiguous=is_ambiguous,
                    # Alternatives shown only for ambiguous detections to
                    # keep the UI focused.
                    alternatives=alternatives if is_ambiguous else [],
                )
            )

        if unknown_class_count:
            logger.warning(
                f"{unknown_class_count} detections had unknown class IDs "
                f"and were skipped"
            )

        n = len(detections)
        ambig = sum(1 for d in detections if d.is_ambiguous)
        with_alts = sum(1 for d in detections if d.alternatives)
        logger.info(
            f"Detected {n} glyphs "
            f"(conf>={settings.detector_conf_threshold}, "
            f"{ambig} ambiguous, {with_alts} with alternatives)"
        )
        return detections