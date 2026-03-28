# 官方 Gazebo ROS2 使用说明

日期：2026-03-28

状态：

- 已在本机验证通过
- 推荐场景：
  - `indoor`

适用目标：

- 启动官方 `autonomous_exploration_development_environment`
- 接入下载好的环境模型
- 接入 `ARiADNE-ROS-Planner`
- 以可复现脚本方式运行与停止

## 1. 路径约定

官方环境仓库：

- `/home/liuyi/projects/thermal_nav/autonomous_exploration_development_environment`

ARiADNE：

- `/home/liuyi/projects/thermal_nav/ARiADNE-ROS-Planner`

当前工程仓库：

- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration`

环境模型源目录：

- `/home/liuyi/Downloads/autonomous_exploration_environments`

## 2. 当前推荐脚本

模型链接：

- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/link_official_env_models.sh`

官方环境编译：

- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/build_official_dev_env.sh`

Gazebo + ARiADNE 启动：

- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch_official_ariadne.sh`

Gazebo + ARiADNE 停止：

- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/stop_official_ariadne.sh`

默认 RViz 配置：

- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/rviz/official_gazebo_ariadne_clean.rviz`

当前使用的 wrapper launch：

- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch/official_system_no_xacro.launch.py`
- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch/official_vehicle_simulator_no_xacro.launch.py`

## 3. 前置条件

### 3.1 ROS2 与 Gazebo 系统依赖

至少应有：

- ROS2 Humble
- `gazebo`
- `libgazebo-dev`
- `ros-humble-gazebo-dev`
- `ros-humble-gazebo-msgs`
- `ros-humble-gazebo-plugins`
- `ros-humble-gazebo-ros`
- `ros-humble-gazebo-ros2-control`
- `ros-humble-gazebo-ros-pkgs`
- `ros-humble-octomap-server`

### 3.2 ARiADNE Python 环境

当前推荐使用：

- conda env:
  - `ros2-torch`

当前已验证其中可用：

- `torch`
- `torchvision`
- `matplotlib`
- `scikit-image`
- `rospkg`

注意：

- 现在已经不再依赖 user-site Python 包。

## 4. 一次性准备

### 4.1 接模型

命令：

```bash
/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/link_official_env_models.sh
```

作用：

- 把下载好的：
  - `campus`
  - `forest`
  - `garage`
  - `indoor`
  - `tunnel`
- 软链接到官方仓库：
  - `src/vehicle_simulator/mesh/`

### 4.2 编译官方环境

命令：

```bash
/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/build_official_dev_env.sh
```

作用：

- 用 ROS2 Humble 编译官方工作区

### 4.3 如需重编译 ARiADNE

命令：

```bash
set +u
source /opt/ros/humble/setup.bash
source /home/liuyi/miniforge3/etc/profile.d/conda.sh
conda activate ros2-torch
cd /home/liuyi/projects/thermal_nav/ARiADNE-ROS-Planner
python -m colcon build
```

## 5. 推荐启动方式

### 5.1 标准启动：`indoor`

命令：

```bash
export START_SYSTEM=1
export START_RVIZ=0
export SCENE=indoor
export GAZEBO_GUI=false
/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch_official_ariadne.sh
```

说明：

- `START_SYSTEM=1`
  - 同时启动官方 Gazebo 系统
- `SCENE=indoor`
  - 当前推荐首测场景
- `GAZEBO_GUI=false`
  - 无界面 headless 模式
- `START_RVIZ=0`
  - 默认不启 RViz

### 5.2 可视化启动：Gazebo GUI + Clean RViz

命令：

```bash
export START_SYSTEM=1
export START_RVIZ=1
export SCENE=indoor
export GAZEBO_GUI=true
/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch_official_ariadne.sh
```

说明：

- `GAZEBO_GUI=true`
  - 启动 `gzclient`
- `START_RVIZ=1`
  - 启动默认的 clean RViz 配置
- 当前这条 GUI 链已经在本机验证通过

预期进程：

- `gzserver`
- `gzclient`
- `rviz2`
- `octomap_server_node`
- `rl_planner`

### 5.3 启动后你应该看到的关键输出

正常情况下会依次出现：

- `Official system started`
- `Topic ready: /state_estimation`
- `Topic ready: /sensor_scan`
- `Activated conda env: ros2-torch`
- `octomap started`
- `Topic ready: /projected_map`
- `rl_planner started`
- `Topic ready: /way_point`

最后会出现：

```text
Official Gazebo + ARiADNE is up.
Scene: indoor
Base frame: sensor
```

## 6. 停止方式

### 6.1 当前终端里运行

直接：

```bash
Ctrl-C
```

当前脚本已验证：

- 一次 `Ctrl-C` 会同时结束：
  - 顶层启动脚本
  - Gazebo 系统子进程
  - `octomap_server`
  - `rl_planner`
  - RViz

### 6.2 从其他终端停止

命令：

```bash
/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/stop_official_ariadne.sh
```

说明：

- 脚本会根据 pid 文件停止：
  - 官方系统 launch
  - `octomap_server`
  - `rl_planner`
  - RViz
- 如果 pid 文件不存在，脚本会自动退回到进程模式清理旧会话

pid 文件默认位置：

- `/home/liuyi/projects/thermal_nav/ARiADNE-ROS-Planner/tmp/official_gazebo_ariadne_run/pids.env`

## 7. 场景建议

### 7.1 推荐顺序

1. `garage`
2. `indoor`
3. `forest`
4. `tunnel`

### 7.2 实际用途

`garage`：

- 用来验证 Gazebo 主链能否正常启动
- 不推荐做 ARiADNE 首个有效联调

`indoor`：

- 当前最推荐的 ARiADNE 首测场景
- 已实测跑通 `/rl_planner`、`/way_point`

`forest` / `tunnel`：

- 建议在 `indoor` 稳定后再调

## 8. 常用参数

主要环境变量在启动脚本里：

- `SCENE`
- `START_SYSTEM`
- `GAZEBO_GUI`
- `START_RVIZ`
- `RVIZ_CONFIG_FILE`
- `BASE_FRAME`
- `SENSOR_RANGE`
- `MAP_RESOLUTION`
- `NODE_RESOLUTION`
- `PUBLISH_GRAPH`
- `WAYPOINT_THRESHOLD`
- `NEXT_WAYPOINT_THRESHOLD`
- `HARD_UPDATE_THRESHOLD`
- `FRONTIER_CLUSTER_RANGE`
- `REPLANNING_FREQUENCY`

当前已验证的一组默认值：

- `SCENE=indoor`
- `GAZEBO_GUI=false`
- `START_RVIZ=0`
- `BASE_FRAME=sensor`
- `SENSOR_RANGE=20.0`
- `MAP_RESOLUTION=0.4`
- `NODE_RESOLUTION=2.0`

## 9. 验证命令

### 9.1 节点图

```bash
export PYTHONNOUSERSITE=1
set +u
source /opt/ros/humble/setup.bash
source /home/liuyi/projects/thermal_nav/autonomous_exploration_development_environment/install/setup.bash
source /home/liuyi/projects/thermal_nav/ARiADNE-ROS-Planner/install/setup.bash
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/ros/humble/bin:$PATH
ros2 node list
```

至少应看到：

- `/gazebo`
- `/localPlanner`
- `/terrainAnalysis`
- `/sensorScanGeneration`
- `/vehicleSimulator`
- `/octomap_server`
- `/rl_planner`

### 9.2 查看 waypoint

```bash
export PYTHONNOUSERSITE=1
set +u
source /opt/ros/humble/setup.bash
source /home/liuyi/projects/thermal_nav/autonomous_exploration_development_environment/install/setup.bash
source /home/liuyi/projects/thermal_nav/ARiADNE-ROS-Planner/install/setup.bash
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/ros/humble/bin:$PATH
timeout 8 ros2 topic echo --once /way_point
```

### 9.3 查看是否结束

```bash
export PYTHONNOUSERSITE=1
set +u
source /opt/ros/humble/setup.bash
source /home/liuyi/projects/thermal_nav/autonomous_exploration_development_environment/install/setup.bash
source /home/liuyi/projects/thermal_nav/ARiADNE-ROS-Planner/install/setup.bash
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/ros/humble/bin:$PATH
timeout 8 ros2 topic echo --once /exploration_finish
```

`indoor` 正常联调时，预期更接近：

```text
data: false
```

## 10. 推荐工作流

### 10.1 第一次上机

1. 链接模型
2. 编译官方环境
3. 确认 `ros2-torch` 依赖完整
4. 用 `garage` 验证 Gazebo 主链
5. 切到 `indoor` 验证 ARiADNE

### 10.2 日常使用

1. 运行 `launch_official_ariadne.sh`
2. 在另一个终端用 `ros2 node list` / `ros2 topic echo` 做抽查
3. 结束时运行 `stop_official_ariadne.sh`

## 11. 当前实现特点

### 11.1 为什么不是直接用官方原始 launch

当前推荐链使用的是 wrapper，而不是官方原始 `vehicle_simulator.launch`，原因是：

- 当前机器没有 `xacro`
- wrapper 已经绕过 `xacro`
- wrapper 已修复 `/spawn_entity` 时序问题
- wrapper 现在还显式透传了 `gazebo_gui/world`
- wrapper 还会在启动 RViz 时清理 `snap` 注入的桌面环境变量，避免 `rviz2` 秒退

### 11.2 当前实现比最初版本多出的工程化能力

- `spawn_entity_when_ready.sh`
- 启停 pid 管理
- `stop_official_ariadne.sh`
- 已移除对 user-site 的依赖
- clean RViz 默认配置
- Gazebo GUI 已验证可用

### 11.3 这里的 wrapper 是什么意思

这里的 `wrapper` 指的是：

- 在官方上游 launch 外面再包一层本地适配脚本/launch
- 它不是另一个仿真器，也不是重写官方系统
- 它的作用是把“这台机器上实际能稳定跑”的启动细节收口起来

当前 wrapper 主要负责：

- 绕过官方 launch 对 `xacro` 的依赖
- 修复 `/spawn_entity` 的启动时序
- 显式透传 `world` 和 `gazebo_gui`
- 统一 Gazebo + ARiADNE 的启停方式
- 为 RViz 提供干净的启动环境和默认配置

## 12. 常见问题

### 12.1 RViz 里看起来像有两个坐标系/两辆车一起动

通常不是系统里真有两台车，而是旧配置把多套“调试用”显示叠在一起了。

当前默认 clean RViz 配置只保留：

- `Grid`
- `Vehicle` 轴
- `/projected_map`
- `/path`
- `/way_point`

默认关闭的调试项：

- `/sensor_scan`
- `/terrain_map`
- `/explored_areas`
- `/node`
- `/edge`
- `/occupied_cells_vis_array`
- `/frontier`

如果你手动切回旧的：

- `/home/liuyi/projects/thermal_nav/ARiADNE-ROS-Planner/src/rl_planner/rviz/rviz.rviz`

就会重新看到更偏算法调试的视图，它本来就更乱。

### 12.2 小车在 A/B 两个位置之间来回跳，或者看起来悬浮

这通常不是 Gazebo 官方环境本身的 bug，而是旧会话残留的系统进程没有被清干净。

典型根因：

- 旧的 `/vehicleSimulator` 还活着
- 旧的 `terrainAnalysis / sensorScanGeneration / static_transform_publisher` 也还活着
- 新会话启动后，旧会话和新会话会同时往：
  - `/state_estimation`
  - `/tf`
  - `/set_entity_state`
  写数据

直接后果：

- RViz 的车体/坐标系在两组 pose 之间跳
- Gazebo 里的 `robot/lidar/camera` 被两套状态同时驱动
- 看起来就像车在闪现、漂移、甚至悬空

当前脚本已经内建两层防护：

- `stop_official_ariadne.sh` 会额外清理官方系统残留进程
- `launch_official_ariadne.sh` 在 `pids.env` 不存在时，也会主动检查 stale process，发现残留就拒绝启动

处理方式：

```bash
/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/stop_official_ariadne.sh
```

然后重新启动。

### 12.3 `Found existing pid file`

说明：

- 上一轮会话还没清理干净

处理：

```bash
/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/stop_official_ariadne.sh
```

### 12.4 `No pid file found ... Falling back to process-pattern shutdown`

说明：

- 这通常表示当前残留的是旧测试会话，或者上一次异常退出时 pid 文件已被删掉

处理：

- 这是脚本内建的正常 fallback
- 让脚本自动继续清理即可

### 12.5 `Topic ready: /state_estimation` 卡住或超时

优先检查：

- 官方环境是否已编译
- Gazebo 依赖是否安装
- 模型链接是否完成
- 是否已有残留旧会话

### 12.6 `rl_planner` 起不来

优先检查：

```bash
set +u
source /opt/ros/humble/setup.bash
source /home/liuyi/miniforge3/etc/profile.d/conda.sh
conda activate ros2-torch
export PYTHONNOUSERSITE=1
python - <<'PY'
mods=['matplotlib','skimage','rospkg','rclpy','sensor_msgs_py']
for m in mods:
    mod=__import__(m)
    print(m, getattr(mod, '__file__', None))
PY
```

### 12.7 RViz 一启动就退出

当前本机已知原因是：

- 终端来自 `code` 的 snap 会话
- `rviz2` 会错误继承 `snap/core20` 的库环境

当前脚本已内建处理：

- `START_RVIZ=1` 时会为 RViz 单独起一个干净子环境
- 不再依赖当前终端的 `SNAP_*` / `GTK_*` 变量

如果你自己手工起 RViz，也建议用脚本而不是直接 `ros2 run rviz2 rviz2`。

### 12.8 `garage` 上很快结束

这是当前已知现象，不建议把 `garage` 作为 ARiADNE 主联调场景。

### 12.9 按了 `Ctrl-C` 之后 GUI 关了，但终端还挂着

这是之前脚本里的信号处理问题：

- 老版本是 `trap cleanup EXIT INT TERM`
- `cleanup` 只负责清理子进程，不负责让顶层 bash 退出
- 所以 GUI 虽然会关，但 bash 还会回到最后的 `while true; do sleep 2; done`

当前已经修复：

- `INT/TERM` 现在会走：
  - 清理
  - 退出

如果你用的是当前仓库最新脚本，一次 `Ctrl-C` 就应该能完整结束。

## 13. 当前推荐命令清单

模型链接：

```bash
/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/link_official_env_models.sh
```

编译官方环境：

```bash
/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/build_official_dev_env.sh
```

启动 `indoor`：

```bash
export START_SYSTEM=1
export START_RVIZ=0
export SCENE=indoor
export GAZEBO_GUI=false
/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch_official_ariadne.sh
```

停止：

```bash
/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/stop_official_ariadne.sh
```

## 14. 推荐定位

当前这条线建议定位为：

- 主开发线
- 主验证线
- ARiADNE 与官方环境的标准集成线

Unity 线建议保留为：

- 历史工程链
- 对照实验链
