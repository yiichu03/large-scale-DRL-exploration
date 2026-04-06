#!/usr/bin/env python3

import argparse
import csv
import math
import signal
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional, Tuple


@dataclass
class Sample:
    t_sec: float
    x: float
    y: float
    z: float


def svg_escape(text: str) -> str:
    return (
        text.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
        .replace("'", "&apos;")
    )


def build_monitor_class(Node, QoSProfile, ReliabilityPolicy, Odometry, OccupancyGrid, Bool):
    class XYZTrajectoryMonitor(Node):
        def __init__(self, args: argparse.Namespace):
            super().__init__("gazebo_xyz_trajectory_monitor")
            self.args = args
            self.output_dir = Path(args.output_dir).resolve()
            self.output_dir.mkdir(parents=True, exist_ok=True)

            self.method = args.method
            self.scene = args.scene
            self.start_time_epoch = float(time.time())
            self.finished = False
            self.finish_time_epoch: Optional[float] = None
            self.stop_requested = False
            self.stop_reason = "running"

            self.samples: List[Sample] = []
            self.last_pose: Optional[Tuple[float, float, float]] = None
            self.last_recorded_pose: Optional[Tuple[float, float, float]] = None
            self.last_sample_epoch: Optional[float] = None
            self.travel_distance_m = 0.0

            # latest projected_map for background visualization
            self.latest_map: Optional[object] = None

            qos = QoSProfile(depth=10, reliability=ReliabilityPolicy.BEST_EFFORT)
            qos_reliable = QoSProfile(depth=1, reliability=ReliabilityPolicy.RELIABLE)
            self.create_subscription(Odometry, "/state_estimation", self.odom_callback, qos)
            self.create_subscription(Bool, "/exploration_finish", self.finish_callback, qos)
            self.create_subscription(OccupancyGrid, "/projected_map", self.map_callback, qos_reliable)

            self.get_logger().info(
                f"xyz trajectory monitor started: method={self.method} scene={self.scene} output={self.output_dir}"
            )

        def odom_callback(self, msg: Odometry) -> None:
            now = time.time()
            pose = (
                float(msg.pose.pose.position.x),
                float(msg.pose.pose.position.y),
                float(msg.pose.pose.position.z),
            )

            if self.last_pose is not None:
                dx = pose[0] - self.last_pose[0]
                dy = pose[1] - self.last_pose[1]
                dz = pose[2] - self.last_pose[2]
                self.travel_distance_m += math.sqrt(dx * dx + dy * dy + dz * dz)
            self.last_pose = pose

            if self.should_record_sample(now, pose):
                self.samples.append(
                    Sample(
                        t_sec=now - self.start_time_epoch,
                        x=pose[0],
                        y=pose[1],
                        z=pose[2],
                    )
                )
                self.last_recorded_pose = pose
                self.last_sample_epoch = now

        def finish_callback(self, msg: Bool) -> None:
            if msg.data and not self.finished:
                self.finished = True
                self.finish_time_epoch = time.time()
                self.stop_reason = "finished"
                self.get_logger().info("exploration_finish=true")

        def map_callback(self, msg: OccupancyGrid) -> None:
            self.latest_map = msg

        def should_record_sample(self, now: float, pose: Tuple[float, float, float]) -> bool:
            if self.last_sample_epoch is None or self.last_recorded_pose is None:
                return True

            if (now - self.last_sample_epoch) >= self.args.sample_period_sec:
                return True

            dx = pose[0] - self.last_recorded_pose[0]
            dy = pose[1] - self.last_recorded_pose[1]
            dz = pose[2] - self.last_recorded_pose[2]
            return math.sqrt(dx * dx + dy * dy + dz * dz) >= self.args.sample_distance_m

        def finalize(self) -> None:
            self.write_summary()
            self.write_csv()
            self.write_svg()
            self.write_map()

        def write_summary(self) -> None:
            summary_path = self.output_dir / "summary.txt"
            finish_elapsed = None
            if self.finish_time_epoch is not None:
                finish_elapsed = self.finish_time_epoch - self.start_time_epoch

            last_sample = self.samples[-1] if self.samples else None
            lines = [
                f"method: {self.method}",
                f"scene: {self.scene}",
                f"finished: {self.finished}",
                f"finish_elapsed_sec: {finish_elapsed}",
                f"travel_distance_m: {self.travel_distance_m:.3f}",
                f"sample_count: {len(self.samples)}",
                f"stop_reason: {self.stop_reason}",
                f"output_dir: {self.output_dir}",
            ]
            if last_sample is not None:
                lines.extend(
                    [
                        f"last_x: {last_sample.x:.4f}",
                        f"last_y: {last_sample.y:.4f}",
                        f"last_z: {last_sample.z:.4f}",
                    ]
                )
            summary_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

        def write_csv(self) -> None:
            csv_path = self.output_dir / "trajectory_xyz.csv"
            with csv_path.open("w", encoding="utf-8", newline="") as f:
                writer = csv.writer(f)
                writer.writerow(["t_sec", "x", "y", "z"])
                for sample in self.samples:
                    writer.writerow(
                        [f"{sample.t_sec:.3f}", f"{sample.x:.4f}", f"{sample.y:.4f}", f"{sample.z:.4f}"]
                    )

        def write_map(self) -> None:
            if self.latest_map is None:
                return
            import json as _json
            msg = self.latest_map
            meta = {
                "resolution": msg.info.resolution,
                "width": msg.info.width,
                "height": msg.info.height,
                "origin_x": msg.info.origin.position.x,
                "origin_y": msg.info.origin.position.y,
            }
            (self.output_dir / "map_meta.json").write_text(
                _json.dumps(meta, indent=2), encoding="utf-8"
            )
            import array as _array
            data = _array.array("b", msg.data)
            (self.output_dir / "map_data.bin").write_bytes(data.tobytes())

        def build_panel(
            self,
            title: str,
            samples: List[Sample],
            x_getter,
            y_getter,
            x_label: str,
            y_label: str,
            x0: int,
            y0: int,
            width: int,
            height: int,
        ) -> str:
            plot_pad = 45
            if not samples:
                return (
                    f'<g transform="translate({x0},{y0})">'
                    f'<rect x="0" y="0" width="{width}" height="{height}" fill="#ffffff" stroke="#d0d0d0"/>'
                    f'<text x="16" y="28" font-size="18" fill="#222">{svg_escape(title)}</text>'
                    f'<text x="16" y="56" font-size="14" fill="#666">No samples</text>'
                    "</g>"
                )

            xs = [x_getter(s) for s in samples]
            ys = [y_getter(s) for s in samples]
            min_x, max_x = min(xs), max(xs)
            min_y, max_y = min(ys), max(ys)
            span_x = max(max_x - min_x, 1e-6)
            span_y = max(max_y - min_y, 1e-6)

            plot_w = width - 2 * plot_pad
            plot_h = height - 2 * plot_pad

            def project(sample: Sample) -> Tuple[float, float]:
                px = plot_pad + (x_getter(sample) - min_x) / span_x * plot_w
                py = height - plot_pad - (y_getter(sample) - min_y) / span_y * plot_h
                return px, py

            polyline = " ".join(f"{project(s)[0]:.2f},{project(s)[1]:.2f}" for s in samples)
            start_x, start_y = project(samples[0])
            end_x, end_y = project(samples[-1])

            return f"""
<g transform="translate({x0},{y0})">
  <rect x="0" y="0" width="{width}" height="{height}" fill="#ffffff" stroke="#d0d0d0"/>
  <rect x="{plot_pad}" y="{plot_pad}" width="{plot_w}" height="{plot_h}" fill="#fafafa" stroke="#e0e0e0"/>
  <polyline fill="none" stroke="#1f77b4" stroke-width="2.5" points="{polyline}"/>
  <circle cx="{start_x:.2f}" cy="{start_y:.2f}" r="4.5" fill="#2ca02c"/>
  <circle cx="{end_x:.2f}" cy="{end_y:.2f}" r="4.5" fill="#d62728"/>
  <text x="16" y="28" font-size="18" fill="#222">{svg_escape(title)}</text>
  <text x="{width/2:.0f}" y="{height-10}" text-anchor="middle" font-size="13" fill="#555">{svg_escape(x_label)} [{min_x:.2f}, {max_x:.2f}]</text>
  <text x="18" y="{height/2:.0f}" transform="rotate(-90 18 {height/2:.0f})" text-anchor="middle" font-size="13" fill="#555">{svg_escape(y_label)} [{min_y:.2f}, {max_y:.2f}]</text>
</g>
"""

        def write_svg(self) -> None:
            svg_path = self.output_dir / "trajectory_xyz.svg"
            width = 1400
            height = 1100
            panel_w = 650
            panel_h = 460
            samples = self.samples

            header = (
                f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}">'
                '<rect width="100%" height="100%" fill="#f5f5f7"/>'
                f'<text x="30" y="42" font-size="28" fill="#111">{svg_escape(self.method)} | {svg_escape(self.scene)} trajectory</text>'
                f'<text x="30" y="74" font-size="16" fill="#444">samples={len(samples)} finished={self.finished} distance={self.travel_distance_m:.2f}m start=green end=red</text>'
            )
            panels = [
                self.build_panel("XY Top View", samples, lambda s: s.x, lambda s: s.y, "x", "y", 30, 100, panel_w, panel_h),
                self.build_panel("XZ Elevation", samples, lambda s: s.x, lambda s: s.z, "x", "z", 720, 100, panel_w, panel_h),
                self.build_panel("YZ Side View", samples, lambda s: s.y, lambda s: s.z, "y", "z", 30, 590, panel_w, panel_h),
                self.build_panel("Z vs Time", samples, lambda s: s.t_sec, lambda s: s.z, "t_sec", "z", 720, 590, panel_w, panel_h),
            ]
            svg_path.write_text(header + "".join(panels) + "</svg>\n", encoding="utf-8")

    return XYZTrajectoryMonitor


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Record /state_estimation xyz trajectory and export CSV/SVG.")
    parser.add_argument("--method", required=True)
    parser.add_argument("--scene", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--sample-period-sec", type=float, default=0.2)
    parser.add_argument("--sample-distance-m", type=float, default=0.05)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        import rclpy
        from nav_msgs.msg import OccupancyGrid, Odometry
        from rclpy.node import Node
        from rclpy.qos import QoSProfile, ReliabilityPolicy
        from std_msgs.msg import Bool
    except ModuleNotFoundError as exc:
        print(
            "Missing ROS2 Python dependency. Source /opt/ros/humble/setup.bash before running this script.",
            file=sys.stderr,
        )
        print(f"Import error: {exc}", file=sys.stderr)
        return 2

    XYZTrajectoryMonitor = build_monitor_class(Node, QoSProfile, ReliabilityPolicy, Odometry, OccupancyGrid, Bool)
    rclpy.init(args=None)
    monitor = XYZTrajectoryMonitor(args)

    def request_stop(signum, _frame):
        signal_name = signal.Signals(signum).name
        monitor.get_logger().info(f"received {signal_name}, finalizing trajectory outputs")
        monitor.stop_reason = f"signal_{signal_name.lower()}"
        monitor.stop_requested = True

    signal.signal(signal.SIGINT, request_stop)
    signal.signal(signal.SIGTERM, request_stop)

    try:
        while rclpy.ok() and not monitor.stop_requested:
            rclpy.spin_once(monitor, timeout_sec=0.2)
    finally:
        monitor.finalize()
        print(f"trajectory outputs written: {monitor.output_dir}")
        monitor.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()
    return 0


if __name__ == "__main__":
    sys.exit(main())
