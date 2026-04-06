#!/usr/bin/env python3
"""
Plot robot trajectory on top of occupancy map background.
Produces a paper-style figure (like ARiADNE paper).

Usage (with map background):
  python3 plot_trajectory_on_map.py \
    --run-dir /path/to/trajectory_monitor_20260406_120000_tunnel \
    --output figure.png

Usage (TARE trajectory on ARiADNE map):
  python3 plot_trajectory_on_map.py \
    --run-dir /path/to/tare_run_dir \
    --map-dir /path/to/ariadne_run_dir \
    --output figure.png

Usage (trajectory only, no map):
  python3 plot_trajectory_on_map.py \
    --run-dir /path/to/run_dir \
    --no-map \
    --output figure.png
"""

import argparse
import array
import csv
import json
from pathlib import Path

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.collections import LineCollection


# ---------------------------------------------------------------------------
# Data loading
# ---------------------------------------------------------------------------

def load_trajectory(csv_path: Path):
    """Returns (t, x, y) arrays. Empty arrays if file has no data rows."""
    rows = []
    with csv_path.open(encoding="utf-8") as f:
        for row in csv.DictReader(f):
            rows.append((float(row["t_sec"]), float(row["x"]), float(row["y"])))
    if not rows:
        return np.array([]), np.array([]), np.array([])
    t, x, y = zip(*rows)
    return np.array(t), np.array(x), np.array(y)


def load_map(meta_path: Path, data_path: Path):
    """Returns (meta dict, grid ndarray int8)."""
    with meta_path.open(encoding="utf-8") as f:
        meta = json.load(f)
    raw = array.array("b")
    raw.frombytes(data_path.read_bytes())
    grid = np.array(raw, dtype=np.int8).reshape((meta["height"], meta["width"]))
    return meta, grid


def occupancy_to_rgba(grid: np.ndarray) -> np.ndarray:
    """
    Convert OccupancyGrid int8 values to RGBA image.
      -1  unknown  → mid-gray  (185, 185, 185)
       0  free     → white     (240, 240, 240)
     ≥50  occupied → dark gray ( 60,  60,  60)
    """
    h, w = grid.shape
    img = np.zeros((h, w, 4), dtype=np.uint8)
    unknown = grid < 0
    occupied = grid >= 50
    free = ~unknown & ~occupied

    img[unknown]  = [185, 185, 185, 255]
    img[free]     = [240, 240, 240, 255]
    img[occupied] = [ 60,  60,  60, 255]
    return img


# ---------------------------------------------------------------------------
# Main plot
# ---------------------------------------------------------------------------

def plot(
    t: np.ndarray,
    x: np.ndarray,
    y: np.ndarray,
    meta: dict | None,
    grid: np.ndarray | None,
    output_path: Path,
    title: str = "",
    cmap: str = "rainbow",
    linewidth: float = 2.5,
    dpi: int = 200,
) -> None:
    fig, ax = plt.subplots(figsize=(9, 9))
    ax.set_aspect("equal")
    ax.set_facecolor("#c8c8c8")

    # --- background map ---
    if meta is not None and grid is not None:
        img = occupancy_to_rgba(grid)
        extent = [
            meta["origin_x"],
            meta["origin_x"] + meta["width"]  * meta["resolution"],
            meta["origin_y"],
            meta["origin_y"] + meta["height"] * meta["resolution"],
        ]
        ax.imshow(img, origin="lower", extent=extent, aspect="equal", zorder=1)

    # --- trajectory ---
    if len(t) >= 2:
        t_norm = (t - t[0]) / max(t[-1] - t[0], 1e-6)

        points   = np.stack([x, y], axis=1).reshape(-1, 1, 2)
        segments = np.concatenate([points[:-1], points[1:]], axis=1)
        lc = LineCollection(
            segments,
            cmap=cmap,
            norm=plt.Normalize(0, 1),
            linewidth=linewidth,
            zorder=3,
            capstyle="round",
        )
        lc.set_array(t_norm[:-1])
        ax.add_collection(lc)

        # start / end markers
        ax.plot(x[0],  y[0],  "o", color="#2ca02c", markersize=9, zorder=5, label="start")
        ax.plot(x[-1], y[-1], "o", color="#d62728", markersize=9, zorder=5, label="end")
        ax.legend(loc="upper right", fontsize=10, framealpha=0.8)

        # colorbar
        sm = plt.cm.ScalarMappable(cmap=cmap, norm=plt.Normalize(0, t[-1] - t[0]))
        sm.set_array([])
        cbar = fig.colorbar(sm, ax=ax, fraction=0.03, pad=0.02)
        cbar.set_label("time (s)", fontsize=10)

        # compute cumulative distance
        dist = float(np.sum(np.hypot(np.diff(x), np.diff(y))))
        elapsed = float(t[-1] - t[0])
        auto_title = f"distance {dist:.0f} m    time {elapsed:.0f} s"
    else:
        auto_title = "No trajectory data"

    if not title:
        title = auto_title

    ax.set_title(title, fontsize=13, pad=10)
    ax.set_xlabel("x (m)", fontsize=10)
    ax.set_ylabel("y (m)", fontsize=10)

    # auto-scale view to trajectory + some margin
    if len(x) > 0:
        margin = 2.0
        ax.set_xlim(x.min() - margin, x.max() + margin)
        ax.set_ylim(y.min() - margin, y.max() + margin)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output_path, dpi=dpi, bbox_inches="tight")
    print(f"saved: {output_path}")
    plt.close(fig)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args():
    p = argparse.ArgumentParser(
        description="Plot trajectory CSV on occupancy map background."
    )
    p.add_argument("--run-dir", required=True,
                   help="Directory containing trajectory_xyz.csv (and optionally map files)")
    p.add_argument("--map-dir", default=None,
                   help="Directory with map_meta.json + map_data.bin (defaults to --run-dir)")
    p.add_argument("--no-map", action="store_true",
                   help="Skip map background even if map files exist")
    p.add_argument("--output", default=None,
                   help="Output PNG path (default: <run-dir>/figure.png)")
    p.add_argument("--title", default="",
                   help="Figure title (auto-generated if omitted)")
    p.add_argument("--cmap", default="rainbow",
                   help="Matplotlib colormap for trajectory (default: rainbow)")
    p.add_argument("--linewidth", type=float, default=2.5)
    p.add_argument("--dpi", type=int, default=200)
    return p.parse_args()


def main():
    args = parse_args()

    run_dir = Path(args.run_dir).resolve()
    map_dir = Path(args.map_dir).resolve() if args.map_dir else run_dir
    output  = Path(args.output).resolve() if args.output else run_dir / "figure.png"

    # load trajectory
    traj_csv = run_dir / "trajectory_xyz.csv"
    if not traj_csv.exists():
        print(f"ERROR: trajectory CSV not found: {traj_csv}")
        return 1
    t, x, y = load_trajectory(traj_csv)
    print(f"loaded {len(t)} trajectory points from {traj_csv}")

    # load map
    meta, grid = None, None
    if not args.no_map:
        meta_path = map_dir / "map_meta.json"
        data_path = map_dir / "map_data.bin"
        if meta_path.exists() and data_path.exists():
            meta, grid = load_map(meta_path, data_path)
            print(f"loaded map {grid.shape[1]}x{grid.shape[0]} @ {meta['resolution']}m/cell from {map_dir}")
        else:
            print("map files not found — plotting trajectory only")

    plot(t, x, y, meta, grid, output,
         title=args.title, cmap=args.cmap,
         linewidth=args.linewidth, dpi=args.dpi)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
