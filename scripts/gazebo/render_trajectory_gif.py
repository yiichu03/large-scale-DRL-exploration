#!/usr/bin/env python3

import argparse
import csv
import math
import os
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import List

os.environ.setdefault("MPLBACKEND", "Agg")
os.environ.setdefault("MPLCONFIGDIR", str((Path.cwd() / "tmp" / ".mplconfig").resolve()))

import imageio.v2 as imageio
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np


@dataclass
class Sample:
    t_sec: float
    x: float
    y: float
    z: float


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Convert trajectory_xyz.csv into an animated GIF.")
    parser.add_argument("--input-csv", required=True, help="Path to trajectory_xyz.csv")
    parser.add_argument("--output-gif", default=None, help="Output GIF path. Defaults next to CSV.")
    parser.add_argument("--title", default="Trajectory Replay", help="Figure title.")
    parser.add_argument("--scene-label", default="unknown-scene", help="Scene label shown in the GIF.")
    parser.add_argument("--fps", type=int, default=10, help="GIF playback FPS.")
    parser.add_argument("--max-frames", type=int, default=140, help="Maximum animation frames after downsampling.")
    parser.add_argument(
        "--trail-seconds",
        type=float,
        default=10.0,
        help="How many seconds of recent motion to highlight as the active trail.",
    )
    parser.add_argument(
        "--dpi",
        type=int,
        default=100,
        help="Figure DPI. Lower this if the GIF becomes too large.",
    )
    return parser.parse_args()


def load_samples(csv_path: Path) -> List[Sample]:
    samples: List[Sample] = []
    with csv_path.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            samples.append(
                Sample(
                    t_sec=float(row["t_sec"]),
                    x=float(row["x"]),
                    y=float(row["y"]),
                    z=float(row["z"]),
                )
            )
    if not samples:
        raise ValueError(f"No samples found in {csv_path}")
    return samples


def choose_frame_indices(num_samples: int, max_frames: int) -> np.ndarray:
    if num_samples <= max_frames:
        return np.arange(num_samples, dtype=int)
    return np.unique(np.linspace(0, num_samples - 1, max_frames, dtype=int))


def compute_padding(min_v: float, max_v: float) -> tuple[float, float]:
    span = max(max_v - min_v, 1e-3)
    pad = span * 0.08
    return min_v - pad, max_v + pad


def compute_cumulative_distance(samples: List[Sample]) -> np.ndarray:
    dist = np.zeros(len(samples), dtype=float)
    for i in range(1, len(samples)):
        dx = samples[i].x - samples[i - 1].x
        dy = samples[i].y - samples[i - 1].y
        dz = samples[i].z - samples[i - 1].z
        dist[i] = dist[i - 1] + math.sqrt(dx * dx + dy * dy + dz * dz)
    return dist


def find_trail_start(samples: List[Sample], end_idx: int, trail_seconds: float) -> int:
    cutoff = samples[end_idx].t_sec - trail_seconds
    start_idx = end_idx
    while start_idx > 0 and samples[start_idx - 1].t_sec >= cutoff:
        start_idx -= 1
    return start_idx


def render_frame(
    samples: List[Sample],
    cumulative_distance: np.ndarray,
    end_idx: int,
    trail_seconds: float,
    bounds: dict,
    title: str,
    scene: str,
    fig_dpi: int,
) -> np.ndarray:
    fig = plt.figure(figsize=(12.8, 9.2), dpi=fig_dpi, constrained_layout=True)
    grid = fig.add_gridspec(2, 2, width_ratios=[1.45, 1.0], height_ratios=[1.0, 1.0])

    ax_xy = fig.add_subplot(grid[:, 0])
    ax_xz = fig.add_subplot(grid[0, 1])
    ax_zt = fig.add_subplot(grid[1, 1])

    trail_start = find_trail_start(samples, end_idx, trail_seconds)
    current = samples[end_idx]

    all_x = np.array([s.x for s in samples], dtype=float)
    all_y = np.array([s.y for s in samples], dtype=float)
    all_z = np.array([s.z for s in samples], dtype=float)
    all_t = np.array([s.t_sec for s in samples], dtype=float)

    hist_x = all_x[: end_idx + 1]
    hist_y = all_y[: end_idx + 1]
    hist_z = all_z[: end_idx + 1]
    hist_t = all_t[: end_idx + 1]

    trail_x = all_x[trail_start : end_idx + 1]
    trail_y = all_y[trail_start : end_idx + 1]
    trail_z = all_z[trail_start : end_idx + 1]
    trail_t = all_t[trail_start : end_idx + 1]

    fig.patch.set_facecolor("#f3f4f6")

    ax_xy.set_title("XY Top View", fontsize=15, pad=10)
    ax_xy.plot(all_x, all_y, color="#d4d8dd", linewidth=2.0, alpha=0.8, label="Full run")
    sc = ax_xy.scatter(
        hist_x,
        hist_y,
        c=hist_z,
        cmap="viridis",
        s=16,
        alpha=0.9,
        edgecolors="none",
        label="Visited samples",
    )
    ax_xy.plot(trail_x, trail_y, color="#0057b8", linewidth=3.0, alpha=0.95, label="Recent trail")
    ax_xy.scatter([samples[0].x], [samples[0].y], color="#2ca02c", s=70, marker="o", label="Start")
    ax_xy.scatter([current.x], [current.y], color="#d62728", s=110, marker="o", label="Current")
    ax_xy.annotate(
        f"z={current.z:.2f} m",
        (current.x, current.y),
        xytext=(8, 8),
        textcoords="offset points",
        fontsize=10,
        color="#111827",
        bbox=dict(boxstyle="round,pad=0.2", fc="white", ec="#d1d5db", alpha=0.9),
    )
    ax_xy.set_xlim(bounds["x"])
    ax_xy.set_ylim(bounds["y"])
    ax_xy.set_aspect("equal", adjustable="box")
    ax_xy.set_xlabel("x [m]")
    ax_xy.set_ylabel("y [m]")
    ax_xy.grid(True, color="#e5e7eb", linewidth=0.8)
    cbar = fig.colorbar(sc, ax=ax_xy, fraction=0.035, pad=0.015)
    cbar.set_label("height z [m]")
    ax_xy.legend(loc="upper right", frameon=True, framealpha=0.92)

    ax_xz.set_title("XZ Elevation", fontsize=14, pad=10)
    ax_xz.plot(all_x, all_z, color="#d4d8dd", linewidth=2.0, alpha=0.8)
    ax_xz.plot(trail_x, trail_z, color="#8b5cf6", linewidth=3.0)
    ax_xz.scatter([samples[0].x], [samples[0].z], color="#2ca02c", s=55)
    ax_xz.scatter([current.x], [current.z], color="#d62728", s=75)
    ax_xz.set_xlim(bounds["x"])
    ax_xz.set_ylim(bounds["z"])
    ax_xz.set_xlabel("x [m]")
    ax_xz.set_ylabel("z [m]")
    ax_xz.grid(True, color="#e5e7eb", linewidth=0.8)

    ax_zt.set_title("Height vs Time", fontsize=14, pad=10)
    ax_zt.plot(all_t, all_z, color="#d4d8dd", linewidth=2.0, alpha=0.8)
    ax_zt.plot(trail_t, trail_z, color="#059669", linewidth=3.0)
    ax_zt.scatter([current.t_sec], [current.z], color="#d62728", s=75)
    ax_zt.set_xlim(bounds["t"])
    ax_zt.set_ylim(bounds["z"])
    ax_zt.set_xlabel("time [s]")
    ax_zt.set_ylabel("z [m]")
    ax_zt.grid(True, color="#e5e7eb", linewidth=0.8)

    fig.suptitle(f"{title} | {scene}", fontsize=20, fontweight="bold", x=0.47)

    progress = (end_idx + 1) / len(samples)
    z_min = float(np.min(hist_z))
    z_max = float(np.max(hist_z))
    x_span = float(np.max(hist_x) - np.min(hist_x))
    y_span = float(np.max(hist_y) - np.min(hist_y))
    elapsed = current.t_sec
    total_distance = cumulative_distance[end_idx]
    speed = 0.0
    if end_idx > 0:
        dt = max(samples[end_idx].t_sec - samples[end_idx - 1].t_sec, 1e-6)
        ds = cumulative_distance[end_idx] - cumulative_distance[end_idx - 1]
        speed = ds / dt

    info_lines = [
        f"t = {elapsed:.1f} s",
        f"progress = {progress * 100:.1f}%",
        f"xyz = ({current.x:.2f}, {current.y:.2f}, {current.z:.2f}) m",
        f"path length = {total_distance:.2f} m",
        f"inst speed = {speed:.2f} m/s",
        f"z range = [{z_min:.2f}, {z_max:.2f}] m",
        f"xy span = {x_span:.2f} x {y_span:.2f} m",
    ]
    fig.text(
        0.745,
        0.63,
        "\n".join(info_lines),
        fontsize=11,
        color="#111827",
        va="top",
        ha="left",
        bbox=dict(boxstyle="round,pad=0.4", fc="white", ec="#d1d5db", alpha=0.96),
    )

    fig.canvas.draw()
    frame = np.asarray(fig.canvas.buffer_rgba(), dtype=np.uint8)[..., :3].copy()
    plt.close(fig)
    return frame


def main() -> int:
    args = parse_args()
    csv_path = Path(args.input_csv).resolve()
    if not csv_path.is_file():
        print(f"Input CSV not found: {csv_path}", file=sys.stderr)
        return 2

    output_gif = Path(args.output_gif).resolve() if args.output_gif else csv_path.with_suffix(".gif")
    output_gif.parent.mkdir(parents=True, exist_ok=True)
    mplconfig_dir = output_gif.parent / ".mplconfig"
    mplconfig_dir.mkdir(parents=True, exist_ok=True)
    os.environ["MPLCONFIGDIR"] = str(mplconfig_dir)

    samples = load_samples(csv_path)
    frame_indices = choose_frame_indices(len(samples), args.max_frames)
    cumulative_distance = compute_cumulative_distance(samples)

    all_x = np.array([s.x for s in samples], dtype=float)
    all_y = np.array([s.y for s in samples], dtype=float)
    all_z = np.array([s.z for s in samples], dtype=float)
    all_t = np.array([s.t_sec for s in samples], dtype=float)

    bounds = {
        "x": compute_padding(float(np.min(all_x)), float(np.max(all_x))),
        "y": compute_padding(float(np.min(all_y)), float(np.max(all_y))),
        "z": compute_padding(float(np.min(all_z)), float(np.max(all_z))),
        "t": compute_padding(float(np.min(all_t)), float(np.max(all_t))),
    }

    title = args.title
    scene = args.scene_label

    with imageio.get_writer(output_gif, mode="I", fps=max(args.fps, 1), loop=0) as writer:
        for idx in frame_indices:
            frame = render_frame(
                samples=samples,
                cumulative_distance=cumulative_distance,
                end_idx=int(idx),
                trail_seconds=args.trail_seconds,
                bounds=bounds,
                title=title,
                scene=scene,
                fig_dpi=args.dpi,
            )
            writer.append_data(frame)

        hold_frame = render_frame(
            samples=samples,
            cumulative_distance=cumulative_distance,
            end_idx=len(samples) - 1,
            trail_seconds=args.trail_seconds,
            bounds=bounds,
            title=title,
            scene=scene,
            fig_dpi=args.dpi,
        )
        for _ in range(max(args.fps, 1) * 2):
            writer.append_data(hold_frame)

    print(f"Wrote GIF: {output_gif}")
    print(f"Frames: {len(frame_indices) + max(args.fps, 1) * 2}")
    print(f"Samples: {len(samples)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
