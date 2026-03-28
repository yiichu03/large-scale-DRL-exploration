# Gazebo ROS2 Handoff Memory

更新时间：2026-03-28  
用途：给新对话中的 AI 快速恢复当前项目状态，避免重复梳理 Unity 线、ARiADNE 线和官方 Gazebo ROS2 线。

---

## 1. 当前主线目标

当前新的主线不是继续扩展 Unity A/B，而是：

1. 判断并搭建官方 `autonomous_exploration_development_environment` 的 ROS2 Humble 流程
2. 接入已下载的 Gazebo 环境模型包
3. 评估如何把 `ARiADNE-ROS-Planner` 接进去
4. 对比它和当前 Unity 流程的差异

当前最重要的现实结论：

- 现在 Unity 线已经可运行
- 官方 Gazebo ROS2 线还没有真正搭起来
- 当前机器上只有 Gazebo 环境模型包，没有官方开发环境仓库本体

---

## 2. 三个核心仓库与当前 HEAD

### 2.1 `large-scale-DRL-exploration`

- 路径：`/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration`
- 当前 HEAD：`a386ed6`
- 作用：
  - 当前作为主工作区
  - 放文档、A/B 脚本、实验编排工具
  - 也是论文 `Deep Reinforcement Learning-based Large-Scale Robot Exploration` 对应训练仓库

重要说明：

- README 明写它是 **ARiADNE ground truth critic variant** 的新实现
- 当前本地仓库里 **没有现成 large-scale 公开 checkpoint**
- 训练代码会自己保存 `model/.../checkpoint.pth`

### 2.2 `ARiADNE-ROS-Planner`

- 路径：`/home/liuyi/projects/thermal_nav/ARiADNE-ROS-Planner`
- 分支：`humble`
- 当前 HEAD：`889f3f1`
- 作用：
  - ROS2 部署仓库
  - 负责 `octomap_server -> /projected_map -> rl_planner -> /way_point`

重要说明：

- 自带默认 `checkpoint.pth`
- 当前 Unity 联调实际跑的是它的默认 checkpoint
- **不能严格证明这个自带 checkpoint 就是 RAL 2024 large-scale 论文的官方权重**
- 最稳妥称呼：`ARiADNE-ROS-Planner 默认 checkpoint`

### 2.3 `autonomy_stack_mecanum_wheel_platform`

- 路径：`/home/liuyi/projects/thermal_nav/autonomy_stack_mecanum_wheel_platform`
- 当前 HEAD：`71a9b57`
- 作用：
  - 当前 Unity 仿真底座
  - 提供 `/state_estimation`、`/sensor_scan`、`localPlanner` 等执行链

---

## 3. 当前 Unity 线已经完成到哪一步

### 3.1 Unity + ARiADNE 已跑通

当前已经跑通过这条链：

```text
Unity
-> system_simulation.launch
-> vehicleSimulator / terrain_analysis / sensor_scan_generation / localPlanner
-> /sensor_scan
-> octomap_server
-> /projected_map
-> rl_planner
-> /way_point + /exploration_finish
-> localPlanner
-> /cmd_vel
-> Unity 中机器人运动
```

### 3.2 当前 A/B 工具

都放在：

- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/ab_compare/`

关键文件：

- `run_ariadne_ab.sh`
- `run_tare_ab.sh`
- `run_tare_outdoor_ab.sh`
- `stop_tare_ab.sh`
- `monitor_experiment.py`

输出目录：

- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/ab_runs/`

当前功能：

- 自动统计 `/exploration_finish`
- 自动统计累计里程
- 自动保存：
  - `summary.json`
  - `summary.txt`
  - `trajectory.csv`
  - `trajectory.svg`
  - `run_metadata.json`
- 默认在 finish 后等待 20 秒再自动停止

### 3.3 当前已加的重要改动

#### `ARiADNE-ROS-Planner`

- 已补 `/exploration_finish` 发布
- 已修 `NumPy 2.x` 兼容性

#### `large-scale-DRL-exploration`

- 已有 Unity 一键脚本
- 已有 A/B 监控器
- 已有结果目录 metadata 记录
- 目录名已带 config 信息

---

## 4. 当前最关键的命名/模型结论

这是新对话里非常容易混淆的点，必须明确：

### 4.1 当前论文方法是什么

你现在重点看的论文是：

- `/home/liuyi/Documents/papers/thermal-nav-docs/liuyi/Deep_Reinforcement_Learning-Based_Large-Scale_Robot_Exploration.pdf`

它对应的是：

- `large-scale-DRL-exploration`
- 本质上是 **ARiADNE ground truth critic variant / large-scale 版本**

### 4.2 当前 Unity 实验实际跑的是谁

当前 Unity 里实际跑的是：

- `ARiADNE-ROS-Planner` 自带默认 `checkpoint.pth`

所以不要写成：

- “已经在 Unity 里验证了 large-scale 论文官方模型”

更准确的说法是：

- “已经在 Unity 里验证了 `ARiADNE-ROS-Planner` 默认 checkpoint”
- “该 checkpoint 与 large-scale 训练框架兼容，但其训练来源尚未严格确认”

---

## 5. 当前对 `ARiADNE` 与 `TARE` 的一个重要观察

在 `office_building_1/2` 里已经观察到：

- `ARiADNE` 更容易进入楼梯间、室外低处、或从高处进入低处后回不来
- `TARE` 相对更谨慎，或者更晚才进入低处

这 **不太像巧合**，更像表示层差异：

### `ARiADNE`

- 主要吃 `/projected_map`（2D OccupancyGrid）
- 网络输入是图节点的 4 维特征：
  - `dx`
  - `dy`
  - `utility`
  - `visited`
- 不直接使用地形高度、坡度、台阶信息

### `TARE`

- 订阅：
  - `/terrain_map`
  - `/terrain_map_ext`
  - `/registered_scan`
  - `/state_estimation_at_scan`
- 其 viewpoint / connectivity 逻辑显式使用高度差、terrain collision、viewpoint height

结论：

- `TARE` 的表示层更接近 3D / 2.5D
- 当前接法下的 `ARiADNE` 更接近 2D 高层探索
- 所以楼梯/下沉区域问题更容易在 `ARiADNE` 上暴露

---

## 6. 官方 Gazebo ROS2 线的当前状态

### 6.1 已有资源

当前机器上已经下载：

- `/home/liuyi/Downloads/autonomous_exploration_environments`

里面有：

- `campus`
- `forest`
- `garage`
- `indoor`
- `tunnel`

这些目录里是：

- `model.sdf`
- `model.config`
- `meshes/`

也就是说：

- **这是 Gazebo 环境模型包**
- **不是完整系统仓库**

### 6.2 已有官方 ROS2 说明

当前仓库里有：

- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/ros2_setup_notes.pdf`

文档要点：

- Ubuntu 22.04 -> ROS2 Humble
- 需要先克隆 `autonomous_exploration_development_environment`
- checkout `humble`
- 先下载 simulation environments
- 再 `colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release`
- 然后例如：
  - `ros2 launch vehicle_simulator system_garage.launch`

再克隆/编译 planner：

- `tare_planner`
- `dsv_planner`
- `far_planner`

### 6.3 当前缺什么

当前机器上 **没有**：

- `autonomous_exploration_development_environment` 仓库本体
- `system_indoor.launch`
- `system_garage.launch`
- `system_forest.launch`
- `system_tunnel.launch`

也就是说：

- 现在只有 Gazebo 场景资源
- 还没有官方 Gazebo 系统底座

### 6.4 当前不能直接做什么

当前不能直接把：

- `/home/liuyi/Downloads/autonomous_exploration_environments`

拿来喂当前 Unity 流程。

原因：

- 当前 Unity 流程依赖 `Model.x86_64`
- 你下载的是 Gazebo `model.sdf`
- 资源格式、启动链、仿真底座都不同

---

## 7. 当前我们与官方 README 流程的真实差异

### 官方 README / notes 流程

更接近：

```text
CMU Gazebo Development Environment
-> vehicle_simulator system_indoor/system_garage/...
-> sensor odometry + lidar scan + waypoint follower
-> ARiADNE-ROS-Planner
```

### 当前实际跑的是

```text
autonomy_stack Unity 仿真
-> system_simulation.launch
-> sensor_scan_generation / terrain_analysis / localPlanner
-> octomap_server
-> ARiADNE-ROS-Planner
```

所以：

- 当前不是官方 Gazebo 环境
- 当前也不是 README 里原样那条官方 launch
- 但 `ARiADNE-ROS-Planner` 这个高层 exploration 模块本身是同一个

---

## 8. Conda 相关结论

README 建议激活 conda，主要是：

- 安装 PyTorch
- 构建 ROS planner

当前实际运行时：

- 当前 Unity A/B 脚本 **没有显式 `conda activate`**
- 运行时主要依赖：
  - ROS overlay
  - 系统 Python
  - 已安装好的 `ARiADNE-ROS-Planner`

所以：

- 编译阶段用过 conda
- 当前运行阶段不依赖当前 shell 激活 conda

---

## 9. 下一轮对话最该做什么

如果新对话继续走 Gazebo ROS2 官方线，第一步建议是：

1. 检查本机是否已经克隆 `autonomous_exploration_development_environment`
2. 如果没有，先把它拉下来并切到 `humble`
3. 看下载的 `autonomous_exploration_environments` 应该放到哪里
4. 编译官方 Gazebo 系统
5. 先跑 `system_garage.launch` 或 `system_indoor.launch`
6. 再判断怎么接 `ARiADNE-ROS-Planner`

### 建议给新对话 AI 的起始提示词

```text
我们现在要从 Unity 线切到官方 Gazebo ROS2 线。当前已有：
1. /home/liuyi/projects/thermal_nav/ARiADNE-ROS-Planner
2. /home/liuyi/projects/thermal_nav/large-scale-DRL-exploration
3. /home/liuyi/Downloads/autonomous_exploration_environments
4. /home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/ros2_setup_notes.pdf

请先阅读：
/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/docs_liuyi/codex/gazebo_ros2_handoff_memory_20260328.md

目标：
1. 判断并搭建官方 autonomous_exploration_development_environment 的 ROS2 Humble 流程
2. 接入下载好的 Gazebo 环境模型
3. 评估如何把 ARiADNE-ROS-Planner 接进去
4. 和当前 Unity 流程做差异分析

请先检查当前本机缺什么，再给执行计划。
```

---

## 10. 附：当前文档主目录

统一文档主目录：

- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/docs_liuyi/`

Codex 文档目录：

- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/docs_liuyi/codex/`

本交接文档路径：

- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/docs_liuyi/codex/gazebo_ros2_handoff_memory_20260328.md`
