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

- `/home/liuyi/projects/thermal_nav/autonomous_exploration_environments`

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

感知链路 RViz 配置：

- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/rviz/official_gazebo_ariadne_sensing.rviz`

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
- `SCENE_PRESET=auto`
  - 默认会自动套用上游 `ARiADNE-ROS-Planner` `main` 分支 ROS1 launch 里的 `indoor` 参数
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

### 5.3 其他已整理的场景 preset

`forest`：

```bash
export START_SYSTEM=1
export START_RVIZ=1
export SCENE=forest
export GAZEBO_GUI=true
/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch_official_ariadne.sh
```

`tunnel`：

```bash
export START_SYSTEM=1
export START_RVIZ=1
export SCENE=tunnel
export GAZEBO_GUI=true
/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch_official_ariadne.sh
```

说明：

- 脚本会根据 `SCENE` 自动套用上游 `main` 分支 ROS1 launch 的场景参数
- 当前已整理并内置的官方 ARiADNE preset：
  - `indoor`
  - `forest`
  - `tunnel`
- `garage` 和 `campus` 没有上游 ARiADNE preset
  - 当前默认回落到 `indoor` baseline
  - 如果要细调，请额外显式设置参数环境变量

### 5.4 启动后你应该看到的关键输出

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
Scene preset: indoor (upstream main/ROS1 baseline)
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

### 7.3 上游 `main` 场景参数对照

来源：

- `ARiADNE-ROS-Planner` 上游 `main` 分支
- `2026-03-28` 对应远端 head：`773ebcf`
- `src/launch/rl_planner.launch`
- `src/launch/rl_planner_forest.launch`
- `src/launch/rl_planner_tunnel.launch`

当前 wrapper 已按下表内置：

| Scene | sensor_range | node_resolution | frontier_downsample_factor | waypoint_threshold | next_waypoint_threshold | frontier_cluster_range | enable_save_mode | enable_dstarlite | replanning_frequency |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `indoor` | `20.0` | `2.0` | `1` | `2.0` | `4.0` | `10.0` | `false` | `false` | `2.5` |
| `forest` | `22.0` | `4.0` | `2` | `1.0` | `4.0` | `15.0` | `true` | `true` | `1.0` |
| `tunnel` | `20.0` | `1.6` | `1` | `1.5` | `6.0` | `20.0` | `true` | `true` | `2.0` |

基本不变的参数：

- `base_frame=sensor`
- `map_resolution=0.4`
- `utility_range_factor=0.5`
- `min_utility=3`
- `hard_update_threshold=10.0`

`garage` / `campus`：

- 上游 `main` 没有单独 launch
- 当前脚本默认用 `indoor` baseline 起步
- 如果后续发现 `garage` 或 `campus` 的行为不理想，优先从 `node_resolution`、`frontier_downsample_factor`、`waypoint_threshold`、`frontier_cluster_range`、`replanning_frequency` 这几项开始调

## 8. 常用参数

主要环境变量在启动脚本里：

- `SCENE`
- `SCENE_PRESET`
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
- `SCENE_PRESET=auto`
- `GAZEBO_GUI=false`
- `START_RVIZ=0`
- `BASE_FRAME=sensor`
- `SENSOR_RANGE=20.0`
- `MAP_RESOLUTION=0.4`
- `NODE_RESOLUTION=2.0`

`RVIZ_CONFIG_FILE` 当前推荐两种取值：

- `.../official_gazebo_ariadne_clean.rviz`
  - 适合看整体探索行为，画面最干净
- `.../official_gazebo_ariadne_sensing.rviz`
  - 适合看感知链路，默认打开：
    - `/registered_scan`
    - `/sensor_scan`
    - `/occupied_cells_vis_array`
    - `/projected_map`

## 8.1 不同场景主要调哪些参数

最值得优先调的是：

- `NODE_RESOLUTION`
  - 图节点稀疏程度，影响探索粒度和图规模
- `SENSOR_RANGE`
  - 直接影响局部地图更新范围和 utility 作用半径
- `FRONTIER_DOWNSAMPLE_FACTOR`
  - 前沿点稀疏程度，环境越大越容易需要增大
- `WAYPOINT_THRESHOLD`
  - 判断“到达当前 waypoint”的距离阈值
- `NEXT_WAYPOINT_THRESHOLD`
  - 倾向选更远 waypoint 的阈值
- `FRONTIER_CLUSTER_RANGE`
  - 前沿聚类尺度，开阔环境通常更大
- `ENABLE_SAVE_MODE`
  - 在复杂环境里避免局部循环
- `ENABLE_DSTARLITE`
  - 开大场景时更有帮助
- `REPLANNING_FREQUENCY`
  - 重规划频率，越低越省算力，越高越敏捷

通常不需要先动的参数：

- `MAP_RESOLUTION`
- `UTILITY_RANGE_FACTOR`
- `MIN_UTILITY`
- `HARD_UPDATE_THRESHOLD`

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

- `/registered_scan`
- `/sensor_scan`
- `/terrain_map`
- `/explored_areas`
- `/node`
- `/edge`
- `/occupied_cells_vis_array`
- `/frontier`

如果你想专门检查“仿真雷达 -> octomap -> 2D 地图”这条链，建议直接切到新的 sensing 配置：

```bash
export RVIZ_CONFIG_FILE=/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/rviz/official_gazebo_ariadne_sensing.rviz
```

sensing 配置里默认打开的是：

- `/registered_scan`
  - simulator 在 `map` 系里的配准点云
- `/sensor_scan`
  - `sensor_scan_generation` 生成的传感器系点云
- `/occupied_cells_vis_array`
  - `octomap_server` 的占据体素可视化
- `/projected_map`
  - ARiADNE 直接使用的 2D 投影栅格

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

- 已实测会很快出现：
  - `/exploration_finish=true`
- 因此更适合：
  - 验证 Gazebo 主链是否起得来
- 不适合：
  - 作为 ARiADNE 主联调场景

### 12.9 `forest` / `tunnel` 启动了但车不动

已确认过一轮本地根因：

- `forest` 原因不是场景本身，而是 wrapper 里把
  - `replanning_frequency=1`
  - 作为整数传给了 ROS2 参数系统
- `tunnel` 同理，原来传的是：
  - `replanning_frequency=2`
- `rl_planner` 实际会直接退出，并报：
  - 参数期望 `DOUBLE`
  - 但收到的是 `INTEGER`

当前脚本已修复为：

- `forest`
  - `replanning_frequency=1.0`
- `tunnel`
  - `replanning_frequency=2.0`

如果你是用修复前已经开的旧会话，需要重启脚本才能生效。

复测结果：

- `forest`
  - 已确认 `rl_planner` 不再退出
  - 已重新出现 `/way_point`
  - 已重新出现非零 `/cmd_vel`
- `tunnel`
  - 已确认 `rl_planner` 不再因参数类型退出
  - 但当前仍需要继续观察 waypoint 和起始位姿是否合理

### 12.10 `garage` / `tunnel` 在 Gazebo 里看起来像往下掉

当前更像是：

- 场景原点和可行驶区域的视觉对齐问题
- 不是 ROS 里 `state_estimation` 真掉到很深的负值

本地诊断时实际看到：

- `garage`
  - `/state_estimation` 仍在 `(0.0, 0.0, 0.75)`
- `tunnel`
  - `/state_estimation` 也仍在 `(0.0, 0.0, 0.75)`

所以这类现象优先按“起始位姿/场景坐标对齐问题”处理，不要先按动力学故障处理。

### 12.11 `campus` 可以跑，但完成质量暂时未验证

当前状态：

- `campus` 没有上游 ARiADNE 官方 preset
- 现在用的是 `indoor` baseline
- `rl_planner` 进程能正常活着
- 但“是否真正探索完整”还没形成定量结论

建议：

- 后续先补日志导出
- 再看 `/way_point`、`runtime`、`exploration_finish` 的时间序列
### 12.12 按了 `Ctrl-C` 之后 GUI 关了，但终端还挂着

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

启动 `indoor` 并使用感知链路 RViz：

```bash
export START_SYSTEM=1
export START_RVIZ=1
export SCENE=indoor
export GAZEBO_GUI=true
export RVIZ_CONFIG_FILE=/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/rviz/official_gazebo_ariadne_sensing.rviz
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

## 15. Official Gazebo + current-stack TARE（`garage`）

### 15.1 当前实现结构

当前这条 TARE 线不是直接跑上游 `tare_planner_reference`，而是：

- 官方 Gazebo 环境提供：
  - `garage` world
  - `vehicleSimulator`
  - `sensor_scan_generation`
  - `terrain_analysis`
  - `terrain_analysis_ext`
- 当前栈 `/home/liuyi/projects/thermal_nav/autonomy_stack_mecanum_wheel_platform` 提供：
  - `local_planner.launch`
  - `tare_planner_node`

接口边界是：

- `tare_planner_node -> /way_point`
- `localPlanner -> /path`
- `pathFollower -> /cmd_vel_stamped`
- 官方 `vehicleSimulator` 订阅被 wrapper 改到 `/cmd_vel_stamped`

注意：

- 这里没有写桥接节点
- 只做了一条 launch 级控制话题适配
- 为了避免同名包覆盖，脚本会先起官方 Gazebo 系统，再 source 当前栈并启动当前栈的 `local_planner` 与 `tare_planner`

对应脚本：

- 启动：
  - `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch_official_tare_current_stack.sh`
- 停止：
  - `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/stop_official_tare_current_stack.sh`
- TARE `garage` 参数：
  - `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/config/tare_garage_current_stack.yaml`

### 15.2 推荐启动命令

当前默认只把 `garage` 作为已验证场景：

```bash
export START_SYSTEM=1
export START_RVIZ=0
export START_JOY=0
export SCENE=garage
export GAZEBO_GUI=false
/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch_official_tare_current_stack.sh
```

如果想带 GUI：

```bash
export START_SYSTEM=1
export START_RVIZ=1
export START_JOY=0
export SCENE=garage
export GAZEBO_GUI=true
/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch_official_tare_current_stack.sh
```

当前执行侧参数基线来自你们现有的 `system_scout_hesai_with_tare.launch.py`，即：

- `config=standard`
- `twoWayDrive=true`
- `autonomyMode=true`
- `maxSpeed=0.5`
- `vehicleLength=0.70`
- `vehicleWidth=0.60`

### 15.3 轨迹与高度可视化

如果你想看：

- 小车在楼里具体怎么跑
- 局部/全局路径
- 高度变化

优先看 RViz，不要只看 Gazebo GUI。当前默认已经给 TARE 换成了专用 RViz 配置：

- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/rviz/official_gazebo_tare_garage.rviz`

这份配置默认会打开：

- `Vehicle Trail`
  - 使用 `/state_estimation`
  - `Keep=250`
  - 用一串 3D 轴显示真实执行轨迹
  - 能直接看高度变化
- `Global Path`
  - `/global_path`
- `Local Path`
  - `/local_path`
- `Follower Path`
  - `/path`
- `Waypoint`
  - `/way_point`
- `Exploring Subspaces`
  - `/tare_visualizer/exploring_subspaces`
- `Local Planning Horizon`
  - `/tare_visualizer/local_planning_horizon`

同时，环境层会默认弱化：

- `Overall Map`
  - 只有很低透明度
- `Explored Areas`
  - 半透明高亮
- `Terrain Map`
  - 用亮色点云保留地形高度感

这样做的目的就是：

- 尽量减弱 `garage` 外层白墙的遮挡
- 让你更容易看清车在建筑内部和坡道上的轨迹

如果白墙还是挡视线，直接在 RViz 左侧关掉：

- `Environment -> Overall Map`

如果你只想看高度变化，建议保留：

- `Vehicle Trail`
- `Terrain Map`
- `Local Path`
- `Waypoint`

推荐命令：

```bash
export START_SYSTEM=1
export START_RVIZ=1
export START_JOY=0
export SCENE=garage
export GAZEBO_GUI=true
/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch_official_tare_current_stack.sh
```

### 15.4 运行后保存的轨迹文件

当前 `launch_official_tare_current_stack.sh` 默认会启动一个轨迹监视器：

- `START_MONITOR=1`

它会订阅：

- `/state_estimation`
- `/exploration_finish`

并在结束时自动输出：

- `trajectory_xyz.csv`
  - 列为 `t_sec,x,y,z`
- `trajectory_xyz.svg`
  - 四个视图：
    - `XY Top View`
    - `XZ Elevation`
    - `YZ Side View`
    - `Z vs Time`
- `summary.txt`

默认输出目录：

- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/tmp/official_gazebo_tare_current_stack_run/trajectory_monitor`

如果你想改路径：

```bash
export MONITOR_OUTPUT_DIR=/your/output/dir
```

如果你想关闭自动轨迹记录：

```bash
export START_MONITOR=0
```

### 15.5 把轨迹 CSV 转成动态 GIF

如果你已经有：

- `trajectory_xyz.csv`

可以直接离线生成动态轨迹回放 gif，不需要重新跑 Gazebo。

脚本：

- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/render_trajectory_gif.py`

推荐命令：

```bash
source /home/liuyi/miniforge3/etc/profile.d/conda.sh
conda activate ros2-torch

python /home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/render_trajectory_gif.py \
  --input-csv /home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/tmp/official_gazebo_tare_current_stack_run/trajectory_monitor/trajectory_xyz.csv \
  --output-gif /home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/tmp/official_gazebo_tare_current_stack_run/trajectory_monitor/trajectory_xyz.gif \
  --title "Official Gazebo + current-stack TARE" \
  --scene-label garage
```

输出 gif 默认会包含三类视图：

- `XY Top View`
- `XZ Elevation`
- `Height vs Time`

并且会高亮：

- 完整轨迹轮廓
- 最近一段 active trail
- 当前时刻位置
- 当前累计里程、即时速度、高度范围

说明：

- 脚本依赖 `matplotlib + imageio + pillow`
- 当前机器上建议在 `ros2-torch` 环境里运行
- 默认参数下，`3600+` 个采样点的轨迹会被自动降采样到约 `140` 帧，避免 gif 过大

另外，若你显式打开：

```bash
export ENABLE_DEBUG_LOG=1
```

当前还会额外生成：

- `local_planner.csv`
- `path_follower.csv`
- `tare_planner.csv`

默认目录：

- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/runtime_logs/official_gazebo_tare_current_stack`

其中：

- `tare_planner.csv`
  已包含 `robot_x,robot_y,robot_z`
- `local_planner.csv`
  主要是 planner 决策状态
- `path_follower.csv`
  主要是控制量和 `x,y`

### 15.5 停止命令

```bash
/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/stop_official_tare_current_stack.sh
```

### 15.6 当前已验证结果

`2026-03-29` 的 `garage` smoke test 已确认：

- `/cmd_vel_stamped`
  - publisher：`pathFollower`
  - subscriber：`vehicleSimulator`
- `/way_point`
  - TARE 已持续发布，采样到的一个 waypoint 为：
    - `(37.02, 15.00, 0.83)`
- `/exploration_finish`
  - 采样值为 `false`
- 车体位置在 5 秒内从：
  - `(11.21, 12.64, 0.8394)`
  变到：
  - `(13.36, 11.66, 0.8394)`

这说明：

- TARE 已经在 Gazebo `garage` 里工作
- 当前栈的 `localPlanner + pathFollower` 已经在执行 TARE waypoint
- 官方 Gazebo simulator 已经真实接收并执行了控制命令

### 15.7 当前限制

当前这条 wrapper 先只收敛到 `garage`：

- 如果 `SCENE != garage`
- 且仍使用默认 `tare_garage_current_stack.yaml`
- 脚本会拒绝直接启动

如果后面要试别的场景，需要：

- 显式指定 `TARE_PARAM_FILE`
- 或者后续再整理 `forest / tunnel / campus / indoor` 的 scene-specific TARE 参数

当前 RViz 默认先复用现有 clean 配置：

- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/rviz/official_gazebo_ariadne_clean.rviz`

如果后续你要专门看 TARE marker、`global_path`、`exploring_subspaces`，再单独补一份 TARE 专用 RViz 配置更合适。

## 16. QR_SimEval 场景复用评估（2026-04-08）

当前目标不是复用 `QR_SimEval_Code` 的整套 ROS1 仿真系统，而是判断其中的 Gazebo `.world` / model 资产能否塞进当前 ROS2 官方 Gazebo exploration 流程里，让 ARiADNE 或当前栈的探索模块在这些场景上跑。

### 16.1 结论先说

- `ROS1 -> ROS2` 对“只复用 Gazebo world 资产”不是主障碍。
- 当前 ROS2 流程本来就是“先载 world，再单独 spawn lidar / robot / camera”，因此 world 只要是标准 Gazebo SDF，原则上可以接。
- 真正的障碍是：
  - world 是否自包含
  - 是否依赖作者机器上的绝对路径 mesh
  - 是否需要补当前系统依赖的 Gazebo ROS world plugin
  - 新场景原点附近是否适合直接 spawn 我们的小车

### 16.2 为什么 `test3` 最适合先试

先试 `test3 = maze.world`，不要一开始碰 `test1 / test2 / test14` 这类场景。

原因：

- `QR_SimEval_Code` 的 README 明确写了：
  - `test3` 对应 `maze`
  - `test4` 对应 `neighborhood`
  - 但 `test1 / 2 / 5 / 6 / 7 / 8 / 9 / 12 / 14` 是先起 `earth`，再 “modified in Gazebo”
  - `test15` 是先起 `terrain_1` 再 modified
- 这意味着很多 test 在 repo 里没有保存为最终可复现的固定 `.world`。
- `maze.world` 本身是纯 SDF 墙体、地面和 physics 设置，资源闭合度最高，不依赖作者本地绝对路径。
- `office_env_large.world` / `office_earthquake.world` 大量引用 `/home/biosurvey/...` 的外部 mesh，不适合当第一批导入对象。
- `terrain_1.world` 依赖 `model://terrain_1`，但当前 repo 内没有找到对应 model。

### 16.3 对当前 ROS2 系统的实际影响点

当前 `launch_official_ariadne.sh` 最终会把 `world_name:=...` 传给 `official_vehicle_simulator_no_xacro.launch.py`，再由后者：

- 载入 `vehicle_simulator/world/<name>.world`
- 单独 spawn lidar
- 单独 spawn robot
- 单独 spawn camera
- 启动 `vehicleSimulator`

这说明：

- world 里不需要自带机器人，也不需要沿用 QR 项目的 Unitree 机器人接口。
- 但是当前系统依赖 Gazebo world 提供 `/set_entity_state` 这类接口。
- 现有官方 world 都显式加了：
  - `librotors_gazebo_ros_interface_plugin.so`
  - `libgazebo_ros_state.so`
- 而 `vehicleSimulator` 会持续向 `/set_entity_state` 写 `robot / lidar / camera` 的 pose。

所以最稳妥的做法不是“原封不动加载 QR 的 `maze.world`”，而是：

- 保留当前官方 world 里那两行 plugin 头
- 把 `maze.world` 的几何场景并入一个新的 ROS2 world 模板里

### 16.4 基于 `launch_official_ariadne.sh` 的最小接入计划

后续如果开始改脚本，建议按下面顺序做：

1. 新建一个 ROS2 world，例如 `qr_test3_maze.world`
   - 放到 `autonomous_exploration_development_environment/src/vehicle_simulator/world/`
   - 内容以当前官方 world 模板为外壳，保留插件头
   - 中间替换成 `QR_SimEval` 的 `maze.world` 几何体

2. 新建一个 wrapper 脚本
   - 基于 `large-scale-DRL-exploration/scripts/gazebo/launch_official_ariadne.sh`
   - 默认 `SCENE=qr_test3_maze`
   - 默认 `SCENE_PRESET=none`
   - 避免被现有 `indoor / forest / tunnel / garage / campus` 白名单拦住

3. 第一轮只验证“环境能否正常加载 + 小车能否移动”
   - 先不追求 exploration 完整结果
   - 先看 Gazebo 里 robot / lidar / camera 是否被正确 teleport
   - 先看 `/state_estimation`、`/velodyne_points`、`/projected_map` 是否正常

4. 第二轮再验证 exploration
   - 先沿用 `indoor` 或 `tunnel` 一组保守参数做 smoke test
   - 再决定是否需要单独整理 `qr_test3_maze` 的 scene preset

### 16.5 预期风险

- `maze.world` 当前是正常重力 `-9.8`，而官方 world 多数是 `gravity = 0`。
- `vehicleSimulator` 是 200 Hz 直接写 entity state，因此重力未必会直接导致失败，但如果 robot / lidar / camera 有下坠或抖动，应优先把新 world 的 gravity 改成和官方 world 一致。
- 新场景原点不一定是安全出生点，第一轮很可能需要手调 `vehicleX / vehicleY / vehicleYaw`。
- ARiADNE 当前的 wrapper 对未知 scene 名默认会报 `Unsupported scene`，因此必须显式走 `SCENE_PRESET=none` 或后续补白名单。

### 16.6 当前决定

当前阶段先不改代码。

下一步如果进入实现，优先级如下：

1. 只接 `test3 / maze.world`
2. 先派生一版 `launch_official_ariadne.sh`
3. 先验证能否在 `test3` 上正常载入和跑车
4. 成功后再考虑 `test4 / neighborhood`

不建议当前直接投入 `test1 / test2 / test10 / test11 / test13 / test15`，因为这些场景要么不是固定最终资产，要么缺模型，要么依赖作者本地资源。

### 16.7 `test1` 到 `test15` 复用矩阵

这一版表格明确区分两件事：

- “原版直用”：
  - 指 repo 里是否已经有足够完整的固定 world / model 资产，可直接接入当前 ROS2 Gazebo 流程
- “近似重建”：
  - 指如果不追求作者原版 1:1 场景，只追求功能上等价的 benchmark，自己重搭一个同类场景的难度

| Test | 场景入口 | 原版直用 | 近似重建成本/难度 | repo 内资产情况 | 当前建议 |
|------|----------|----------|----------|----------------|----------|
| `test1` | `earth` 后手工修改 | 否 | 中高 | `ISCAS Museum` 名称在 README 中有，但 repo 内未找到同名固定 world 或 model | 不建议优先做；若真需要，按“室内实验室+楼梯”重搭近似版 |
| `test2` | `earth` 后手工修改 | 否 | 中 | `oak_tree`、`pine_tree`、`vrc_driving_terrain` 在 `gazebo_models` 中存在，但最终布局未保存 | 如果要扩展 benchmark，是较好的近似重建候选 |
| `test3` | `maze.world` | 是 | 低 | 固定 `.world` 存在，几何自包含 | 已接通；继续看 exploration 效果 |
| `test4` | `neighborhood.world` | 是 | 低 | 固定 `.world` 存在，且大部分 house / vehicle / facility 模型在 `gazebo_models` 中存在 | 已接通；继续调出生点和 planner 参数 |
| `test5` | `earth` 后手工修改 | 否 | 中高 | `FRC Field 2016` 名称在 README 中有，但 repo 内未找到同名固定资产 | 当前不建议优先投入 |
| `test6` | `earth` 后手工修改 | 否 | 中 | `gas_station`、`bus`、`suv`、`hatchback` 在 `gazebo_models` 中存在，但最终布局未保存 | 如果要做车辆障碍类 outdoor benchmark，可优先做近似版 |
| `test7` | `earth` 后手工修改 | 否 | 高 | `Kitchen Dining` 名称在 README 中有，但 repo 内未找到同名固定资产 | 当前不建议优先投入 |
| `test8` | `earth` 后手工修改 | 否 | 中 | `powerplant` 在 `gazebo_models` 中存在，但最终布局未保存 | 可做近似版，但优先级低于 `test2 / test6` |
| `test9` | `earth` 后手工修改 | 否 | 中 | `collapsed_fire_station`、`collapsed_house`、`collapsed_industrial`、`collapsed_police_station` 在 `gazebo_models` 中存在，但最终布局未保存 | 若需要灾后废墟类 benchmark，可做近似版 |
| `test10` | `office_env_large.world` | 部分，但当前不可直用 | 高 | 固定 `.world` 在 repo 中，但大量 mesh / material URI 指向作者机器绝对路径 | 只有拿到完整资产或先做路径清洗后才值得继续 |
| `test11` | `office_earthquake.world` | 部分，但当前不可直用 | 高 | 固定 `.world` 在 repo 中，但同样依赖作者机器绝对路径资源 | 同 `test10`，当前不建议优先做 |
| `test12` | `earth` 后手工修改 | 否 | 中 | `gazebo`、`oak_tree`、`vrc_driving_terrain` 在 `gazebo_models` 中存在，但最终布局未保存 | 如果需要 pavilion/tree outdoor 场景，可做近似版 |
| `test13` | `terrain_1.world` | 否 | 高 | world 文件存在，但它只 include `model://terrain_1`，仓库里没有对应 model 目录 | 当前被缺失模型直接阻塞 |
| `test14` | `earth` 后手工修改 | 否 | 原版复刻高；功能等价低 | `long_zoulang3` 名称只出现在 README，repo 内未找到同名固定资产 | 如果要作者原版，不好接；如果只要长走廊 benchmark，自己搭一个更直接 |
| `test15` | `terrain_1` 后手工修改 | 否 | 高 | 既依赖缺失的 `terrain_1`，README 里的 `test2` 资产名也未在 repo 内找到固定模型 | 当前不建议投入 |

表格之外，还要单独强调几条：

- `test1 / test2 / test5 / test6 / test7 / test8 / test9 / test12 / test14` 的共性不是“完全做不了”，而是：
  - repo 没保存作者最终摆好的版本
  - 只能按 README 的模型描述做近似重建
- `test10 / test11` 的问题不是场景概念不清，而是：
  - fixed world 在
  - 但关键资源绑在作者机器绝对路径上
- `test13 / test15` 的问题更硬：
  - 关键 terrain model 本身就缺

当前如果按投入产出比排序：

1. `test3`
2. `test4`
3. 若必须继续扩展，再考虑 `test2 / test6 / test9 / test12`
4. `test14` 如果目标只是做 corridor benchmark，也可以很快做一个功能等价版，但不要把它表述成“作者原版 test14 已复用”

## 17. QR_SimEval `test3` 接入版计划（待审核）

这一节只定义“第一版接入要做什么、不做什么、如何判定继续/停止”，供实现前审核。

### 17.1 目标

目标不是复刻 `QR_SimEval` 的整套 ROS1 仿真系统。

当前要做的是：

- 在当前 ROS2 官方 Gazebo 流程里新增一个可加载的 `test3` 版本场景
- 让当前小车、激光和相机能在该场景中正常启动
- 验证 ARiADNE 是否能在该场景中开始 exploration

### 17.2 第一版范围

第一版只覆盖：

- `QR_SimEval_Code` 的 `test3 = maze.world`
- ARiADNE wrapper 流程
- 最小 smoke test

第一版明确不做：

- `test1 / test2 / test10 / test11 / test13 / test15`
- 场景美化或 1:1 论文复刻
- 专门重调一套 maze 参数
- TARE 同步接入

### 17.3 计划分阶段

#### 阶段 0：准备与冻结条件

目标：

- 确认实现前的工作树状态
- 记录当前基线脚本和 world 位置

执行内容：

- 保持 `autonomous_exploration_development_environment`、`ARiADNE-ROS-Planner`、`autonomy_stack_mecanum_wheel_platform` 不动
- 实现优先落在：
  - `autonomous_exploration_development_environment/src/vehicle_simulator/world/`
  - `large-scale-DRL-exploration/scripts/gazebo/`

停止条件：

- 如果发现当前官方 Gazebo 基线本身已经不稳定，先不接新场景，先恢复基线

#### 阶段 1：制作 ROS2 版 `qr_test3_maze.world`

目标：

- 让 ROS2 官方 Gazebo 能正常加载一个新的 `test3` 场景 world

执行内容：

- 基于当前官方 world 模板做一个新 world，例如：
  - `qr_test3_maze.world`
- 保留当前 world 依赖的 plugin：
  - `librotors_gazebo_ros_interface_plugin.so`
  - `libgazebo_ros_state.so`
- 将 `QR_SimEval` 的 `maze.world` 几何内容并入该 world
- 第一版优先让 gravity 与当前官方 world 保持一致

验收标准：

- Gazebo 能成功打开新 world
- `/set_entity_state` 服务可用
- `robot / lidar / camera` 能被当前 `vehicleSimulator` 正常驱动

停止条件：

- 如果世界文件接入后连 Gazebo 启动都不稳定，暂停，不继续 wrapper

#### 阶段 2：派生 `launch_official_ariadne.sh` 的 test3 wrapper

目标：

- 给 `test3` 提供一条独立、可重复的启动命令

执行内容：

- 基于现有 `launch_official_ariadne.sh` 派生一个 test3 wrapper
- 默认：
  - `SCENE=qr_test3_maze`
  - `SCENE_PRESET=none`
- 保持当前 ARiADNE 主流程不被破坏

验收标准：

- 可以用单条命令启动 test3 版 Gazebo + ARiADNE
- 不影响现有 `indoor / tunnel / garage / campus / forest` 场景

停止条件：

- 如果 wrapper 需要大范围侵入现有启动逻辑，暂停，改为更小改动方案

#### 阶段 3：基础 smoke test

目标：

- 先判断“能不能跑”，不是先判断“跑得好不好”

执行内容：

- 启动 test3 wrapper
- 检查：
  - `/state_estimation`
  - `/velodyne_points`
  - `/projected_map`
  - `/set_entity_state`
- 观察 Gazebo 中小车是否正常移动
- 观察 RViz 中地图是否开始增长

验收标准：

- 小车能在场景内连续运动
- 点云与投影地图在更新
- ARiADNE 没有在启动阶段直接卡死

停止条件：

- 如果机器人明显抖动、下坠、卡地面，先只处理 world 级问题，不进入 exploration 调参

#### 阶段 4：最小 exploration 验证

目标：

- 判断 ARiADNE 是否能在 `test3` 上“开始探索”

执行内容：

- 先沿用一套保守参数
  - 优先考虑 `indoor` 或 `tunnel` 近似配置
- 观察：
  - 是否持续出 waypoint
  - 是否存在明显原地打转
  - 是否有稳定前进和地图扩展

验收标准：

- ARiADNE 可以在 `test3` 上持续运行一段时间
- exploration 行为基本成立

停止条件：

- 如果场景已经能加载，但 exploration 完全不起作用，再决定是否值得做第二轮参数整理

### 17.4 第一版成功判据

第一版只需要满足下面三条中的前两条，第三条为加分项：

- 新 world 可加载
- 小车与传感器可正常运行
- ARiADNE 能在该场景上完成一次可观察的 exploration 过程

### 17.5 第一版失败判据

出现以下任一情况，就认为第一版暂不值得继续深挖：

- 为了接 `test3` 需要大改当前官方 Gazebo 主流程
- 新 world 反复破坏 `/set_entity_state` 驱动链
- 即使处理了 world 层兼容问题，ARiADNE 仍完全无法在该场景上起步

### 17.6 预计涉及文件

如果进入实现，预计优先改这些文件：

- `autonomous_exploration_development_environment/src/vehicle_simulator/world/`
- `large-scale-DRL-exploration/scripts/gazebo/launch_official_ariadne.sh` 的派生 wrapper
- 必要时补一份新的 RViz 配置或运行说明

### 17.7 当前建议

按这个计划继续是值得的，因为：

- `test3` 是目前最干净、最闭合的候选场景
- 关键兼容问题都在 world / wrapper 层，不在算法核心
- 一轮 smoke test 的成本可控

如果审核通过，下一步就进入“阶段 1 + 阶段 2”的实现，不再扩展分析范围。

### 17.8 当前实现结果（2026-04-08）

已完成：

- 新增 ROS2 world：
  - `autonomous_exploration_development_environment/src/vehicle_simulator/world/qr_test3_maze.world`
- 新增 ARiADNE wrapper：
  - `large-scale-DRL-exploration/scripts/gazebo/launch_official_ariadne_qr_test3.sh`
- 新增运行入口说明：
  - `thermal_nav/scripts.md`

实现细节：

- `qr_test3_maze.world` 基于 `QR_SimEval` 的 `maze.world`
- 保留了官方 ROS2 world 依赖的：
  - `librotors_gazebo_ros_interface_plugin.so`
  - `libgazebo_ros_state.so`
- 第一版将 gravity 对齐为官方 world 的 `0 0 0`
- 通过给 `quad_maze` 增加整体 `pose`，把一个高净空单元平移到 `(0, 0)`，避免默认出生点落在墙体内部

静态检查结果：

- wrapper 通过 `bash -n`
- 新 world XML 解析通过
- 平移后的世界原点净空约为 `3.92 m`

构建结果：

- `vehicle_simulator` 已定点重编译成功
- 构建过程中先遇到两个与本次改动无关的环境问题：
  - `colcon` 误用了 miniforge 的 Python
  - `install/vehicle_simulator` 里旧 symlink 残留
- 处理方式：
  - 切回系统 Python + ROS2 环境
  - 清理该包自己的 `build/vehicle_simulator` 与 `install/vehicle_simulator`
  - 重新执行定点构建

headless smoke test 结果：

- 命令：
  - `timeout --signal=INT 90s .../launch_official_ariadne_qr_test3.sh`
- 官方 Gazebo + ARiADNE 主链已成功启动
- 已确认就绪的关键 topic：
  - `/state_estimation`
  - `/sensor_scan`
  - `/projected_map`
  - `/way_point`
- 运行期间已采到：
  - 非零速度的 `/state_estimation`
  - 有效 `/way_point`
- trajectory monitor 已生成输出：
  - `trajectory_xyz.csv`
  - `trajectory_xyz.svg`
  - `map_meta.json`
  - `summary.txt`

当前判断：

- `test3 / maze.world` 已经不是“只会启动，不会跑”的状态
- 至少在第一轮 headless smoke test 里，ARiADNE 已能在该场景上起步并发 waypoint
- 下一步不需要再证明“能不能接入”，而是要看“这个场景上 exploration 效果怎么样，是否值得继续调参数”

### 17.9 `test4 / neighborhood` 当前实现结果（2026-04-08）

已完成：

- 新增 ROS2 world：
  - `autonomous_exploration_development_environment/src/vehicle_simulator/world/qr_test4_neighborhood.world`
- 新增 ARiADNE wrapper：
  - `large-scale-DRL-exploration/scripts/gazebo/launch_official_ariadne_qr_test4.sh`

实现细节：

- `qr_test4_neighborhood.world` 基于 `QR_SimEval` 的 `neighborhood.world`
- 保留了官方 ROS2 world 依赖的：
  - `librotors_gazebo_ros_interface_plugin.so`
  - `libgazebo_ros_state.so`
- 第一版显式把 gravity 对齐为官方 world 的 `0 0 0`
- wrapper 额外导出：
  - `GAZEBO_MODEL_PATH=${THERMAL_NAV_DIR}/QR_SimEval_Code/gazebo_models`

静态与构建结果：

- wrapper 通过 `bash -n`
- 新 world XML 解析通过
- `vehicle_simulator` 已重新定点构建成功
- 新 world 已安装到：
  - `install/vehicle_simulator/share/vehicle_simulator/world/qr_test4_neighborhood.world`

headless smoke test 结果：

- 官方 Gazebo + ARiADNE 主链成功启动
- 已确认就绪的关键 topic：
  - `/state_estimation`
  - `/sensor_scan`
  - `/projected_map`
  - `/way_point`
- trajectory monitor 已生成输出目录与结果文件

但当前观察到的行为是：

- `/state_estimation` 在观察窗口内保持在 `(0, 0, 0.75)`
- `trajectory_xyz.csv` 总位移为 `0 m`
- `summary.txt` 记录：
  - `finished: True`
  - `finish_elapsed_sec: 7.99`
  - `travel_distance_m: 0.000`

当前判断：

- `test4` 已经达到了“场景能加载、模型库能解析、ARiADNE 主链能起”的程度
- 但还没有达到“可以像 test3 一样实际跑起来”的程度
- 下一步优先怀疑：
  - 默认出生点 `(0, 0)` 不适合当前 neighborhood 场景
  - 或者该场景需要一组不同于当前默认值的 scene-specific 参数

进一步定位结果（2026-04-08）：

- 已直接确认 `/exploration_finish` 话题存在，且在 `test4` 启动后很快发布 `true`
- 同时 `/state_estimation` 仍停在：
  - `x=0.0`
  - `y=0.0`
  - `z=0.75`
  - 线速度与角速度均为 `0`
- 这说明 `test4` 当前不是“车开始探索后很快结束”，而是“几乎未移动就被判定探索完成”

代码层面的直接依据：

- `rl_planner` 会持续发布 `exploration_finish`，发布器在：
  - `ARiADNE-ROS-Planner/src/rl_planner/rl_planner/rl_planner.py`
- 其终止条件写为：
  - `if sum(self.robot.key_utility) == 0: self.done = True`
- trajectory monitor 订阅 `/exploration_finish`，收到 `true` 后会把本次运行标记为：
  - `finished = True`
  - `stop_reason = finished`

因此当前更精确的判断是：

- `test4` 接入已经成功
- 现阶段卡点不在 Gazebo world 兼容或 ROS1/ROS2 迁移
- 而在于 `neighborhood` 场景下，ARiADNE 初始化后很快得到 `key_utility = 0`
- 优先排查方向应收敛为：
  - 默认出生点 `(0, 0)` 是否让初始可见区域过大或过于异常
  - 初始 `/projected_map` 或 frontier 提取是否为空
  - 是否需要 `neighborhood` 的专用 planner 参数，而不是沿用当前默认值
