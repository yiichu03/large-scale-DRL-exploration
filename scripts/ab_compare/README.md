# A/B 对比工具

这组脚本只负责实验编排，不改 `autonomy_stack` 和 `ARiADNE-ROS-Planner` 的主体逻辑。

## 入口

- `run_ariadne_ab.sh`
- `run_tare_ab.sh`

## 输出

默认输出到 `ab_runs/<timestamp>_<method>_<scene>/`：

- `summary.json`
- `summary.txt`
- `trajectory.csv`
- `trajectory.svg`

## 常用环境变量

- `SCENE_LABEL=office_building_1`
- `UNITY_WORLD=environment`
- `MONITOR_PYTHON=/usr/bin/python3`
- `AUTO_STOP_ON_FINISH=1`
- `FINISH_GRACE_SEC=20`
- `RUN_TIMEOUT_SEC=0`
- `START_RVIZ=1`
