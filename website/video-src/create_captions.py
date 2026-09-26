#!/usr/bin/env python3
"""Create a WebVTT file from generated scene durations."""

from __future__ import annotations

import sys
from pathlib import Path


def timestamp(seconds: float) -> str:
    milliseconds = round(seconds * 1000)
    hours, milliseconds = divmod(milliseconds, 3_600_000)
    minutes, milliseconds = divmod(milliseconds, 60_000)
    secs, milliseconds = divmod(milliseconds, 1000)
    return f"{hours:02d}:{minutes:02d}:{secs:02d}.{milliseconds:03d}"


def main() -> None:
    timing_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])
    cursor = 0.0
    cues: list[str] = ["WEBVTT", ""]

    for raw_line in timing_path.read_text(encoding="utf-8").splitlines():
        index, duration, caption = raw_line.split("\t", 2)
        end = cursor + float(duration)
        cues.extend(
            [
                index,
                f"{timestamp(cursor)} --> {timestamp(end)} align:center",
                caption.replace("\\n", "\n"),
                "",
            ]
        )
        cursor = end

    output_path.write_text("\n".join(cues), encoding="utf-8")


if __name__ == "__main__":
    main()
