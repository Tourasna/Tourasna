"""
Sorter service — converts raw detections into reading-order Detections.

Ancient Egyptian inscriptions are 2D: glyphs group into quadrats (stacks
of small signs) within rows, and those quadrats are read in sequence.
A flat sort by x-coordinate would break up quadrats; we need to detect
and preserve the 2D structure.

Algorithm:
  1. Row detection       — group detections by Y-coordinate using median height
  2. Quadrat clustering  — within each row, group glyphs with overlapping X ranges
  3. Macro sort          — order quadrats by X (RTL or LTR based on user/default)
  4. Micro sort          — within each quadrat, order top-to-bottom

This mirrors the approach confirmed with Mohy Mohamed (the dataset author)
and reported in the reference paper (ACL 2024 "Deep Learning Meets Egyptology").

The service is stateless: each call is independent, no shared state.
"""
from __future__ import annotations

from loguru import logger

from api.config import settings
from api.schemas import Detection, RawDetection, ReadingDirection


class SorterService:
    """
    Quadrat-based reading order sorter for hieroglyph detections.

    Usage:
        sorter = SorterService()
        detections, num_rows, num_quadrats = sorter.sort(
            raw_detections, direction=ReadingDirection.RTL
        )
    """

    def __init__(self) -> None:
        # Pull thresholds from config. Keeping them here lets us inject
        # different sorters for testing (e.g., strict vs lenient clustering).
        self.row_threshold_ratio: float = settings.sorter_row_threshold_ratio
        self.x_overlap_ratio: float = settings.sorter_x_overlap_ratio

    def sort(
        self,
        raw_detections: list[RawDetection],
        direction: ReadingDirection = ReadingDirection.RTL,
    ) -> tuple[list[Detection], int, int]:
        """
        Apply the 4-step sorting algorithm.

        Args:
            raw_detections: list of detections from the DetectorService (any order)
            direction: RTL (default) or LTR

        Returns:
            sorted_detections: list of Detection objects with row/quadrat_id/
                               position_in_quadrat and sequential id populated
            num_rows: number of rows detected
            num_quadrats: total number of quadrats across all rows

        The detections are returned in reading order — the caller can simply
        iterate for gardiner_sequence construction.
        """
        if not raw_detections:
            return [], 0, 0

        logger.debug(
            f"Sorting {len(raw_detections)} detections, direction={direction.value}"
        )

        # Step 1: group by row (vertical bands)
        rows = self._detect_rows(raw_detections)

        # Step 2-3-4: cluster quadrats, macro sort, micro sort — per row
        sorted_detections: list[Detection] = []
        next_id = 1
        next_quadrat_id = 1

        for row_index, row_dets in enumerate(rows, start=1):
            # Step 2: cluster overlapping x ranges into quadrats
            quadrats = self._cluster_quadrats(row_dets)

            # Step 3: macro-sort the quadrats (RTL or LTR)
            quadrats = self._macro_sort(quadrats, direction)

            # Step 4: micro-sort within each quadrat (top to bottom)
            for quadrat_dets in quadrats:
                quadrat_dets = self._micro_sort(quadrat_dets)
                for pos, raw in enumerate(quadrat_dets, start=1):
                    sorted_detections.append(
                        Detection(
                            id=next_id,
                            gardiner_code=raw.gardiner_code,
                            confidence=raw.confidence,
                            bbox=raw.bbox,
                            row=row_index,
                            quadrat_id=next_quadrat_id,
                            position_in_quadrat=pos,
                            is_ambiguous=raw.is_ambiguous,
                            alternatives=list(raw.alternatives),
                        )
                    )
                    next_id += 1
                next_quadrat_id += 1

        num_rows = len(rows)
        num_quadrats = next_quadrat_id - 1

        stacked = sum(
            1
            for d in sorted_detections
            if d.position_in_quadrat > 1
        )
        logger.info(
            f"Sorted into {num_rows} rows, {num_quadrats} quadrats "
            f"({stacked} glyphs stacked within quadrats)"
        )

        return sorted_detections, num_rows, num_quadrats

    # -------------------------------------------------------------------------
    # Step 1: Row detection
    # -------------------------------------------------------------------------

    def _detect_rows(
        self, detections: list[RawDetection]
    ) -> list[list[RawDetection]]:
        """
        Group detections into rows based on vertical OVERLAP.

        Strategy:
          1. Sort detections by Y-center (top to bottom).
          2. Extend the current row whenever the next detection overlaps
             vertically with ANY detection already in that row.
          3. Otherwise, start a new row.

        Using overlap (not center-distance) handles the common Egyptian
        layout where stacked glyphs in a quadrat span a large Y range
        yet still belong to the same row as their horizontal neighbors.

        A small tolerance (tolerance_px) lets nearly-touching glyphs join
        the same row even when their bboxes don't quite overlap — useful
        for slightly misaligned detections.
        """
        if not detections:
            return []

        # Compute median glyph height — used as the tolerance scale
        heights = sorted(d.bbox.height for d in detections)
        median_h = heights[len(heights) // 2] if heights else 1.0
        if median_h <= 0:
            median_h = 1.0
        # Tolerance: how much gap between bboxes still counts as "same row"
        tolerance_px = median_h * self.row_threshold_ratio

        # Sort by y-center so top-of-image comes first
        ordered = sorted(detections, key=lambda d: d.bbox.center_y)

        rows: list[list[RawDetection]] = [[ordered[0]]]

        for det in ordered[1:]:
            # Current row envelope = tightest vertical band covering all members
            row_top = min(d.bbox.y1 for d in rows[-1])
            row_bottom = max(d.bbox.y2 for d in rows[-1])

            # Does this detection vertically overlap (with tolerance) the row?
            # Overlap check: det.y2 + tolerance >= row_top AND
            #                det.y1 - tolerance <= row_bottom
            if (
                det.bbox.y2 + tolerance_px >= row_top
                and det.bbox.y1 - tolerance_px <= row_bottom
            ):
                rows[-1].append(det)
            else:
                rows.append([det])

        return rows

    # -------------------------------------------------------------------------
    # Step 2: Quadrat clustering
    # -------------------------------------------------------------------------

    def _cluster_quadrats(
        self, row_detections: list[RawDetection]
    ) -> list[list[RawDetection]]:
        """
        Within a single row, group detections that overlap significantly on
        the X axis into quadrats. Glyphs that are stacked vertically but
        share the same horizontal slot belong to the same quadrat.

        Two detections are in the same quadrat if their X intervals overlap
        by at least (x_overlap_ratio * min_width), where min_width is the
        narrower of the two glyphs.

        Implementation: sort by x1 ascending, then greedily merge.
        """
        if not row_detections:
            return []

        # Sort by left edge (x1) ascending
        ordered = sorted(row_detections, key=lambda d: d.bbox.x1)

        quadrats: list[list[RawDetection]] = [[ordered[0]]]
        for det in ordered[1:]:
            # Check if this detection overlaps with any member of the
            # current (rightmost) quadrat. Overlap with any member is
            # enough — quadrats can be wide if glyphs chain sideways.
            joined = False
            for member in quadrats[-1]:
                if self._x_overlaps(det, member):
                    quadrats[-1].append(det)
                    joined = True
                    break
            if not joined:
                quadrats.append([det])

        return quadrats

    def _x_overlaps(self, a: RawDetection, b: RawDetection) -> bool:
        """
        True iff the X intervals of a and b overlap by at least
        x_overlap_ratio * min(a.width, b.width).
        """
        overlap = min(a.bbox.x2, b.bbox.x2) - max(a.bbox.x1, b.bbox.x1)
        if overlap <= 0:
            return False
        min_width = min(a.bbox.width, b.bbox.width)
        if min_width <= 0:
            return False
        return (overlap / min_width) >= self.x_overlap_ratio

    # -------------------------------------------------------------------------
    # Step 3: Macro sort (between quadrats)
    # -------------------------------------------------------------------------

    @staticmethod
    def _macro_sort(
        quadrats: list[list[RawDetection]],
        direction: ReadingDirection,
    ) -> list[list[RawDetection]]:
        """
        Order quadrats left-to-right or right-to-left based on their
        leftmost X (center of mass works too, but leftmost is stabler
        when quadrats have different widths).
        """
        reverse = direction == ReadingDirection.RTL
        return sorted(
            quadrats,
            key=lambda quad: min(d.bbox.center_x for d in quad),
            reverse=reverse,
        )

    # -------------------------------------------------------------------------
    # Step 4: Micro sort (within a quadrat)
    # -------------------------------------------------------------------------

    @staticmethod
    def _micro_sort(quadrat: list[RawDetection]) -> list[RawDetection]:
        """
        Within a quadrat, order top-to-bottom by Y-center.

        This is always the reading convention for stacked glyphs in Egyptian,
        regardless of overall RTL/LTR direction.
        """
        return sorted(quadrat, key=lambda d: d.bbox.center_y)