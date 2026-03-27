# A/B 对比工具

这组脚本只负责实验编排，不改 `autonomy_stack` 和 `ARiADNE-ROS-Planner` 的主体逻辑。

## 入口

- `run_ariadne_ab.sh`
- `run_tare_ab.sh`
- `run_tare_outdoor_ab.sh`

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

## TARE outdoor

如果你只想把 TARE 配置切到 `original_outdoor`，其他行为保持不变：

```bash
cd /home/liuyi/projects/thermal_nav/large-scale-DRL-exploration
SCENE_LABEL=environment ./scripts/ab_compare/run_tare_outdoor_ab.sh
```

这个脚本本质上只是：

- 复用 `run_tare_ab.sh`
- 默认设置 `TARE_CONFIG=original_outdoor`
- `FINISH_GRACE_SEC=20`
- `RUN_TIMEOUT_SEC=0`
- `START_RVIZ=1`
