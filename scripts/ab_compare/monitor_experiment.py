#!/usr/bin/env python3

import argparse
import csv
import json
import math
import os
import shlex
import signal
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import List, Optional, Tuple

import rclpy
from nav_msgs.msg import Odometry
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy
from std_msgs.msg import Bool


def iso_now() -> str:
    return datetime.now().astimezone().isoformat(timespec="seconds")


@dataclass
class Sample:
    t_sec: float
    x: float
    y: float


class ExperimentMonitor(Node):
    def __init__(self, args: argparse.Namespace):
        super().__init__("ab_experiment_monitor")
        self.args = args
        self.output_dir = Path(args.output_dir).resolve()
        self.output_dir.mkdir(parents=True, exist_ok=True)

        self.method = args.method
        self.scene = args.scene
        self.start_time_epoch = float(args.start_time_epoch or time.time())
        self.timeout_sec = float(args.timeout_sec)
        self.auto_stop_on_finish = args.auto_stop_on_finish
        self.finish_grace_sec = float(args.finish_grace_sec)
        self.stop_command = shlex.split(args.stop_command) if args.stop_command else []

        self.finished = False
        self.finish_time_epoch: Optional[float] = None
        self.auto_stop_issued = False
        self.stop_requested = False
        self.stop_reason = "running"

        self.sample_count = 0
        self.travel_distance_m = 0.0
        self.last_pose: Optional[Tuple[float, float]] = None
        self.last_recorded_pose: Optional[Tuple[float, float]] = None
        self.last_sample_epoch: Optional[float] = None
        self.samples: List[Sample] = []

        qos = QoSProfile(depth=10, reliability=ReliabilityPolicy.BEST_EFFORT)
        self.create_subscription(Odometry, "/state_estimation", self.odom_callback, qos)
        self.create_subscription(Bool, "/exploration_finish", self.finish_callback, qos)
        self.create_timer(0.2, self.tick)

        self.get_logger().info(
            f"monitor started: method={self.method} scene={self.scene} output={self.output_dir}"
        )

    def odom_callback(self, msg: Odometry) -> None:
        now = time.time()
        x = float(msg.pose.pose.position.x)
        y = float(msg.pose.pose.position.y)
        pose = (x, y)
        self.sample_count += 1

        if self.last_pose is not None:
            dx = pose[0] - self.last_pose[0]
            dy = pose[1] - self.last_pose[1]
            self.travel_distance_m += math.hypot(dx, dy)
        self.last_pose = pose

        if self.should_record_sample(now, pose):
            self.samples.append(Sample(t_sec=now - self.start_time_epoch, x=x, y=y))
            self.last_recorded_pose = pose
            self.last_sample_epoch = now

    def finish_callback(self, msg: Bool) -> None:
        if msg.data and not self.finished:
            self.finished = True
            self.finish_time_epoch = time.time()
            self.stop_reason = "finished"
            elapsed = self.finish_time_epoch - self.start_time_epoch
            self.get_logger().info(
                f"exploration_finish=true elapsed={elapsed:.2f}s distance={self.travel_distance_m:.2f}m"
            )
            self.write_outputs()

    def tick(self) -> None:
        now = time.time()
        if self.timeout_sec > 0 and (now - self.start_time_epoch) >= self.timeout_sec and not self.stop_requested:
            self.stop_reason = "timeout"
            self.stop_requested = True
            self.get_logger().warning(f"timeout reached: {self.timeout_sec:.1f}s")
            return

        if not self.finished or not self.auto_stop_on_finish or self.auto_stop_issued:
            return

        if self.finish_time_epoch is None:
            return

        if (now - self.finish_time_epoch) >= self.finish_grace_sec:
            self.auto_stop_issued = True
            self.stop_reason = "finished_autostop"
            self.get_logger().info(
                f"finish grace elapsed ({self.finish_grace_sec:.1f}s), issuing stop command"
            )
            self.invoke_stop_command()
            self.stop_requested = True

    def should_record_sample(self, now: float, pose: Tuple[float, float]) -> bool:
        if self.last_sample_epoch is None or self.last_recorded_pose is None:
            return True

        if (now - self.last_sample_epoch) >= self.args.sample_period_sec:
            return True

        dx = pose[0] - self.last_recorded_pose[0]
        dy = pose[1] - self.last_recorded_pose[1]
        return math.hypot(dx, dy) >= self.args.sample_distance_m

    def invoke_stop_command(self) -> None:
        if not self.stop_command:
            return
        try:
            subprocess.run(self.stop_command, check=False)
        except Exception as exc:
            self.get_logger().error(f"stop command failed: {exc}")

    def finish_elapsed_sec(self) -> Optional[float]:
        if self.finish_time_epoch is None:
            return None
        return self.finish_time_epoch - self.start_time_epoch

    def total_elapsed_sec(self) -> float:
        end_time = self.finish_time_epoch or time.time()
        return end_time - self.start_time_epoch

    def summary(self) -> dict:
        return {
            "method": self.method,
            "scene": self.scene,
            "start_time_iso": datetime.fromtimestamp(self.start_time_epoch).astimezone().isoformat(timespec="seconds"),
            "finished": self.finished,
            "finish_elapsed_sec": self.finish_elapsed_sec(),
            "total_elapsed_sec": self.total_elapsed_sec(),
            "travel_distance_m": self.travel_distance_m,
            "sample_count": self.sample_count,
            "trajectory_point_count": len(self.samples),
            "stop_reason": self.stop_reason,
            "auto_stop_on_finish": self.auto_stop_on_finish,
            "finish_grace_sec": self.finish_grace_sec,
            "last_pose": {
                "x": None if self.last_pose is None else self.last_pose[0],
                "y": None if self.last_pose is None else self.last_pose[1],
            },
            "output_dir": str(self.output_dir),
            "written_at": iso_now(),
        }

    def write_outputs(self) -> None:
        self.write_summary_json()
        self.write_summary_txt()
        self.write_trajectory_csv()
        self.write_trajectory_svg()

    def write_summary_json(self) -> None:
        summary_path = self.output_dir / "summary.json"
        with summary_path.open("w", encoding="utf-8") as f:
            json.dump(self.summary(), f, indent=2, ensure_ascii=False)

    def write_summary_txt(self) -> None:
        summary = self.summary()
        lines = [
            f"method: {summary['method']}",
            f"scene: {summary['scene']}",
            f"finished: {summary['finished']}",
            f"finish_elapsed_sec: {summary['finish_elapsed_sec']}",
            f"travel_distance_m: {summary['travel_distance_m']:.3f}",
            f"trajectory_point_count: {summary['trajectory_point_count']}",
            f"stop_reason: {summary['stop_reason']}",
            f"written_at: {summary['written_at']}",
        ]
        with (self.output_dir / "summary.txt").open("w", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")

    def write_trajectory_csv(self) -> None:
        csv_path = self.output_dir / "trajectory.csv"
        with csv_path.open("w", encoding="utf-8", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["t_sec", "x", "y"])
            for sample in self.samples:
                writer.writerow([f"{sample.t_sec:.3f}", f"{sample.x:.4f}", f"{sample.y:.4f}"])

    def write_trajectory_svg(self) -> None:
        svg_path = self.output_dir / "trajectory.svg"
        svg_path.write_text(self.build_svg(), encoding="utf-8")

    def build_svg(self) -> str:
        width = 900
        height = 900
        padding = 60

        if not self.samples:
            return (
                f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}">'
                '<rect width="100%" height="100%" fill="white"/>'
                '<text x="40" y="60" font-size="24" fill="#222">No trajectory samples recorded</text>'
                "</svg>"
            )

        xs = [s.x for s in self.samples]
        ys = [s.y for s in self.samples]
        min_x, max_x = min(xs), max(xs)
        min_y, max_y = min(ys), max(ys)

        span_x = max(max_x - min_x, 1.0)
        span_y = max(max_y - min_y, 1.0)
        scale = min((width - 2 * padding) / span_x, (height - 2 * padding) / span_y)

        def project(sample: Sample) -> Tuple[float, float]:
            px = padding + (sample.x - min_x) * scale
            py = height - padding - (sample.y - min_y) * scale
            return px, py

        polyline = " ".join(f"{project(s)[0]:.2f},{project(s)[1]:.2f}" for s in self.samples)
        start_x, start_y = project(self.samples[0])
        end_x, end_y = project(self.samples[-1])
        finish_text = "true" if self.finished else "false"
        finish_elapsed = self.finish_elapsed_sec()
        finish_str = "n/a" if finish_elapsed is None else f"{finish_elapsed:.1f}s"

        return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}">
  <rect width="100%" height="100%" fill="white"/>
  <rect x="{padding}" y="{padding}" width="{width - 2 * padding}" height="{height - 2 * padding}" fill="#fafafa" stroke="#cfcfcf"/>
  <polyline fill="none" stroke="#1f77b4" stroke-width="3" points="{polyline}"/>
  <circle cx="{start_x:.2f}" cy="{start_y:.2f}" r="7" fill="#2ca02c"/>
  <circle cx="{end_x:.2f}" cy="{end_y:.2f}" r="7" fill="#d62728"/>
  <text x="40" y="36" font-size="22" fill="#111">{self.method} | {self.scene}</text>
  <text x="40" y="66" font-size="16" fill="#333">finished={finish_text} finish_elapsed={finish_str} distance={self.travel_distance_m:.2f}m</text>
  <text x="40" y="96" font-size="14" fill="#555">start=green end=red points={len(self.samples)}</text>
</svg>
"""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Monitor ROS exploration experiment and save A/B metrics.")
    parser.add_argument("--method", required=True, help="Method label, e.g. ARIADNE or TARE")
    parser.add_argument("--scene", required=True, help="Scene label, e.g. environment")
    parser.add_argument("--output-dir", required=True, help="Directory to save summary and trajectory artifacts")
    parser.add_argument("--start-time-epoch", type=float, default=None, help="Wall-clock start time from launcher")
    parser.add_argument("--timeout-sec", type=float, default=0.0, help="Optional overall timeout; 0 disables it")
    parser.add_argument("--auto-stop-on-finish", action="store_true", help="Call stop command after finish grace")
    parser.add_argument("--finish-grace-sec", type=float, default=20.0, help="Delay before auto stop after finish")
    parser.add_argument("--stop-command", default="", help="Command used when auto stop is enabled")
    parser.add_argument("--sample-period-sec", type=float, default=0.2, help="Minimum sample period for trajectory output")
    parser.add_argument("--sample-distance-m", type=float, default=0.05, help="Minimum XY movement for recording a trajectory sample")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    Path(args.output_dir).mkdir(parents=True, exist_ok=True)
    rclpy.init(args=None)
    monitor = ExperimentMonitor(args)

    def request_stop(signum, _frame):
        signal_name = signal.Signals(signum).name
        monitor.get_logger().info(f"received {signal_name}, finalizing outputs")
        monitor.stop_reason = f"signal_{signal_name.lower()}"
        monitor.stop_requested = True

    signal.signal(signal.SIGINT, request_stop)
    signal.signal(signal.SIGTERM, request_stop)

    try:
        while rclpy.ok() and not monitor.stop_requested:
            rclpy.spin_once(monitor, timeout_sec=0.2)
    finally:
        monitor.write_outputs()
        summary_path = monitor.output_dir / "summary.json"
        print(f"summary written: {summary_path}")
        monitor.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()
    return 0


if __name__ == "__main__":
    sys.exit(main())
