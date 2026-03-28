# Gazebo ROS2 执行日志

日期：2026-03-28

目标：

1. 搭建官方 `autonomous_exploration_development_environment` 的 ROS2 Humble 流程
2. 接入已下载的 `autonomous_exploration_environments`
3. 评估并尝试接入 `ARiADNE-ROS-Planner`
4. 记录所有关键命令、问题和解决过程

## 0. 初始判断

- 当前官方 Gazebo ROS2 线尚未在本机搭起。
- 当前机器已有环境模型包：`/home/liuyi/Downloads/autonomous_exploration_environments`
- 当前机器缺官方开发环境仓库本体。
- 当前机器缺 ROS2 Gazebo 相关依赖包。
- 执行工作目录选择在当前可写仓库下：
  - `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/tmp/`

注：

- 后续官方仓库已迁移到：
  - `/home/liuyi/projects/thermal_nav/autonomous_exploration_development_environment`

## 1. 官方信息核对

### 1.1 官方网页/仓库

- 官方网站：
  - `https://www.cmu-exploration.com/development-environment`
  - `https://www.cmu-exploration.com/`
- 官方仓库：
  - `https://github.com/HongbiaoZ/autonomous_exploration_development_environment`

### 1.2 当前结论

- 官方网页主说明仍以 ROS1 `melodic/noetic` 为主。
- 官方网页明确说明：Ubuntu 22.04 + ROS2 Humble 需要参考单独的 ROS2 说明。
- 当前本机已有一份 ROS2 说明：
  - `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/ros2_setup_notes.pdf`

## 2. 执行记录

### 2026-03-28 任务开始

#### 步骤 1：验证官方仓库与分支

命令：

```bash
git ls-remote --heads https://github.com/HongbiaoZ/autonomous_exploration_development_environment.git
```

第一次结果：

- 在沙箱内失败：
  - `fatal: unable to access 'https://github.com/HongbiaoZ/autonomous_exploration_development_environment.git/': Could not resolve host: github.com`

问题：

- 当前执行环境默认禁网，无法直接访问 GitHub。

处理：

- 申请一次联网权限后重跑同一命令。

重跑结果：

- 成功获取远端分支。
- 关键分支存在：
  - `humble` -> `158e67b31b644ed1e8b06eb1d7f70e183cc62591`
  - `humble-matterport`
  - `jazzy`

结论：

- 官方仓库可访问。
- `humble` 分支存在，且当前远端 HEAD 为 `158e67b`。

#### 步骤 2：准备本地工作目录

命令：

```bash
mkdir -p /home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/tmp
```

结果：

- 成功。

#### 步骤 3：克隆官方仓库到当前可写工作区

命令：

```bash
git clone --branch humble \
  https://github.com/HongbiaoZ/autonomous_exploration_development_environment.git \
  /home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/tmp/autonomous_exploration_development_environment
```

结果：

- 成功克隆。
- 本地仓库 HEAD：

```bash
git -C /home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/tmp/autonomous_exploration_development_environment rev-parse --short HEAD
```

- 输出：`158e67b`

#### 步骤 4：核对官方仓库目录结构

检查点：

- `src/vehicle_simulator/launch/system_garage.launch`
- `src/vehicle_simulator/launch/system_indoor.launch`
- `src/vehicle_simulator/launch/system_forest.launch`
- `src/vehicle_simulator/launch/system_tunnel.launch`
- `src/vehicle_simulator/mesh/download_environments.sh`

关键发现：

- 实际模型目录是：
  - `src/vehicle_simulator/mesh/`
- 不是网页里有时写到的 `meshes/`。
- `vehicle_simulator/package.xml` 明确导出了：
  - `<gazebo_ros gazebo_model_path="${prefix}/mesh"/>`

结论：

- 只要把环境模型挂到 `src/vehicle_simulator/mesh/`，Gazebo 就能通过 `model://...` 找到。

#### 步骤 5：核对 world 文件与模型命名

检查文件：

- `src/vehicle_simulator/world/garage.world`
- `src/vehicle_simulator/world/indoor.world`
- `src/vehicle_simulator/world/tunnel.world`
- `src/vehicle_simulator/world/forest.world`

关键发现：

- `garage.world` 使用 `model://garage`
- `indoor.world` 使用 `model://indoor`
- `tunnel.world` 使用 `model://tunnel`
- `forest.world` 内部材质和资源路径使用 `model://forest/...`

结论：

- 顶层目录名必须保留为：
  - `campus`
  - `forest`
  - `garage`
  - `indoor`
  - `tunnel`

#### 步骤 6：接入已下载环境模型

采用策略：

- 使用软链接，不复制大文件。
- 保留下载目录为唯一模型源。

命令：

```bash
ln -s /home/liuyi/Downloads/autonomous_exploration_environments/campus \
  /home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/tmp/autonomous_exploration_development_environment/src/vehicle_simulator/mesh/campus
ln -s /home/liuyi/Downloads/autonomous_exploration_environments/forest \
  /home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/tmp/autonomous_exploration_development_environment/src/vehicle_simulator/mesh/forest
ln -s /home/liuyi/Downloads/autonomous_exploration_environments/garage \
  /home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/tmp/autonomous_exploration_development_environment/src/vehicle_simulator/mesh/garage
ln -s /home/liuyi/Downloads/autonomous_exploration_environments/indoor \
  /home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/tmp/autonomous_exploration_development_environment/src/vehicle_simulator/mesh/indoor
ln -s /home/liuyi/Downloads/autonomous_exploration_environments/tunnel \
  /home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/tmp/autonomous_exploration_development_environment/src/vehicle_simulator/mesh/tunnel
```

验证命令：

```bash
find /home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/tmp/autonomous_exploration_development_environment/src/vehicle_simulator/mesh \
  -maxdepth 1 -mindepth 1 -printf '%f -> %l\n' | sort
```

验证结果：

- `campus -> /home/liuyi/Downloads/autonomous_exploration_environments/campus`
- `forest -> /home/liuyi/Downloads/autonomous_exploration_environments/forest`
- `garage -> /home/liuyi/Downloads/autonomous_exploration_environments/garage`
- `indoor -> /home/liuyi/Downloads/autonomous_exploration_environments/indoor`
- `tunnel -> /home/liuyi/Downloads/autonomous_exploration_environments/tunnel`

当前状态：

- 官方仓库已就位。
- 模型路径已接通。
- 下一步进入依赖检查和编译验证。

#### 步骤 7：首次尝试编译官方工作区

命令：

```bash
cd /home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/tmp/autonomous_exploration_development_environment
set +u && source /opt/ros/humble/setup.bash && \
colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release
```

结果：

- 编译启动成功，说明：
  - `/opt/ros/humble/setup.bash` 存在
  - `colcon` 可用
  - ROS2 Humble 基础环境本身可进入

首个实际失败点：

```text
Failed <<< velodyne_gazebo_plugins
CMake Error at CMakeLists.txt:13 (find_package):
  Could not find a package configuration file provided by "gazebo_dev"
```

伴随现象：

- `velodyne_description`、`vehicle_simulator` 等后续包全部被中止。

结论：

- 当前阻塞不在源码，而在系统依赖：
  - `gazebo_dev`
  - 以及整套 Gazebo ROS2 运行时/开发包

#### 步骤 8：核对缺失依赖的包名

命令：

```bash
apt-cache policy \
  ros-humble-gazebo-dev \
  libgazebo-dev \
  gazebo \
  ros-humble-gazebo-msgs \
  ros-humble-gazebo-plugins \
  ros-humble-gazebo-ros \
  ros-humble-gazebo-ros2-control \
  ros-humble-gazebo-ros-pkgs
```

结果：

- 这些包都有可安装候选版本。
- 当前全部未安装。

进一步确认：

```bash
apt-cache search '^ros-humble-gazebo' | sort
apt-cache search '^libgazebo|^gazebo$' | sort
```

### 2026-03-28 可视化收敛与 GUI 验证

#### 步骤 19：检查现有 RViz 配置为什么会乱

检查文件：

```bash
sed -n '1,260p' /home/liuyi/projects/thermal_nav/ARiADNE-ROS-Planner/src/rl_planner/rviz/rviz.rviz
sed -n '1,260p' /home/liuyi/projects/thermal_nav/autonomous_exploration_development_environment/src/vehicle_simulator/rviz/vehicle_simulator.rviz
```

结论：

- ARiADNE 原始 `rviz.rviz` 偏算法调试：
  - 默认开启 `/node`、`/edge`、`/frontier`、`/occupied_cells_vis_array`
  - 使用 `sensor` 参考轴
- 官方 `vehicle_simulator.rviz` 偏系统开发调试：
  - 默认包含 `/path`、`/free_paths`、`/sensor_scan`、`/trajectory` 等多项显示

判断：

- 这两套都不适合作为当前 Gazebo + ARiADNE 的“默认观察视图”
- 需要一份新的 clean RViz 配置，只保留核心状态显示

#### 步骤 20：新增 clean RViz 配置，并切到脚本默认值

新增文件：

- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/rviz/official_gazebo_ariadne_clean.rviz`

脚本修改：

- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch_official_ariadne.sh`

核心调整：

- 新增：
  - `RVIZ_CONFIG_FILE`
- `START_RVIZ=1` 时默认加载：
  - `official_gazebo_ariadne_clean.rviz`

新的默认显示：

- `Grid`
- `Vehicle` 轴
- `/projected_map`
- `/path`
- `/way_point`

默认关闭的调试显示：

- `/sensor_scan`
- `/terrain_map`
- `/explored_areas`
- `/node`
- `/edge`
- `/occupied_cells_vis_array`
- `/frontier`

#### 步骤 21：把 Gazebo GUI 参数显式透传到 `gazebo_ros`

检查文件：

```bash
sed -n '1,220p' /opt/ros/humble/share/gazebo_ros/launch/gazebo.launch.py
sed -n '1,220p' /opt/ros/humble/share/gazebo_ros/launch/gzserver.launch.py
sed -n '1,220p' /opt/ros/humble/share/gazebo_ros/launch/gzclient.launch.py
```

问题：

- 本地 wrapper 之前虽然声明了 `gui`，但没有在 `IncludeLaunchDescription(...)` 里把它显式传给 `gazebo.launch.py`

处理：

- 修改：
  - `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch/official_vehicle_simulator_no_xacro.launch.py`
- 显式传入：
  - `world`
  - `gui`
  - `pause`
  - `record`
  - `verbose`

#### 步骤 22：首次 GUI 验证，发现 RViz 因 `snap` 环境秒退

启动命令：

```bash
export START_SYSTEM=1
export START_RVIZ=1
export SCENE=indoor
export GAZEBO_GUI=true
/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch_official_ariadne.sh
```

结果：

- Gazebo GUI 路径本身已经接通：
  - `gzclient` 能起来
- 但 `rviz2` 进程不存在，说明 RViz 启动后立即退出

进一步直接抓 RViz 报错：

```bash
export PYTHONNOUSERSITE=1
set +u
source /opt/ros/humble/setup.bash
source /home/liuyi/projects/thermal_nav/autonomous_exploration_development_environment/install/setup.bash
source /home/liuyi/projects/thermal_nav/ARiADNE-ROS-Planner/install/setup.bash
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/ros/humble/bin:$PATH
timeout 8 ros2 run rviz2 rviz2 -d /home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/rviz/official_gazebo_ariadne_clean.rviz
```

关键错误：

```text
/opt/ros/humble/lib/rviz2/rviz2: symbol lookup error: /snap/core20/current/lib/x86_64-linux-gnu/libpthread.so.0: undefined symbol: __libc_pthread_init, version GLIBC_PRIVATE
```

判断：

- 问题不在 RViz 配置文件本身
- 问题来自当前终端所在的 `code` snap 会话，把 `snap/core20` 的桌面运行时污染进了 `rviz2`

#### 步骤 23：为 RViz 启动加“干净子环境”，二次验证通过

处理：

- 修改：
  - `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch_official_ariadne.sh`
- 新增 `start_rviz_bg()`：
  - 使用 `env -i` 启动一个干净子环境
  - 只保留 `DISPLAY`、`XAUTHORITY`、`XDG_RUNTIME_DIR` 等 GUI 必需变量
  - 在子环境里重新 source ROS2、官方工作区和 ARiADNE 工作区

验证命令：

```bash
env -i HOME="$HOME" USER="$USER" LOGNAME="$LOGNAME" DISPLAY="$DISPLAY" \
  XAUTHORITY="$XAUTHORITY" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" TERM="$TERM" \
  SHELL=/bin/bash /bin/bash -lc '
export PYTHONNOUSERSITE=1
set +u
source /opt/ros/humble/setup.bash
source /home/liuyi/projects/thermal_nav/autonomous_exploration_development_environment/install/setup.bash
source /home/liuyi/projects/thermal_nav/ARiADNE-ROS-Planner/install/setup.bash
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/ros/humble/bin:$PATH
timeout 8 ros2 run rviz2 rviz2 -d /home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/rviz/official_gazebo_ariadne_clean.rviz
'
```

结果：

- RViz 成功进入 OpenGL 初始化阶段
- 不再出现 `snap/core20` 的 `libpthread` 符号错误

再次整链验证：

```bash
export START_SYSTEM=1
export START_RVIZ=1
export SCENE=indoor
export GAZEBO_GUI=true
/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch_official_ariadne.sh
```

进程检查：

```bash
ps -ef | rg 'gzserver|gzclient|rviz2|octomap_server_node|install/rl_planner/lib/rl_planner/rl_planner|official_system_no_xacro.launch.py'
```

关键结果：

- `gzserver` 存在
- `gzclient` 存在
- `/opt/ros/humble/lib/rviz2/rviz2` 存在
- `octomap_server_node` 存在
- `rl_planner` 存在

结论：

- Gazebo GUI 已接通并验证通过
- clean RViz 默认配置已接通
- RViz 秒退问题已通过环境清洗修复

### 2026-03-28 跳点/悬浮问题追查

#### 步骤 24：复现并量化 `/state_estimation` 是否真的在跳

使用一个临时 `rclpy` 订阅脚本采样 `/state_estimation` 约 1.5 秒。

关键结果：

- 共收到 `359` 条 odom
- 最大相邻位姿跳变：
  - 时间差约 `0.00253 s`
  - 空间跳变约 `8.57 m`

关键样例：

```text
(1774688775.0264, 4.2307, -0.2089, 0.7063)
(1774688775.0289, 1.9964, 8.0611, 0.7878)
```

结论：

- 不是单纯 RViz/Gazebo 显示错乱
- `/state_estimation` 本身就在两个位置之间跳

#### 步骤 25：确认 `/state_estimation` 的 publisher 数量

命令：

```bash
ros2 topic info /state_estimation -v
```

关键结果：

- `Publisher count: 2`
- 两个 publisher 都叫：
  - `/vehicleSimulator`

进一步命令：

```bash
ros2 node info /vehicleSimulator
```

结果明确提示：

```text
There are 2 nodes in the graph with the exact name "/vehicleSimulator".
```

结论：

- 当前系统里同时存在两个 `vehicleSimulator`
- 这就是 RViz/Gazebo 同时跳动的直接原因

#### 步骤 26：定位第二个 `vehicleSimulator` 的来源

命令：

```bash
ps -ef | rg 'vehicleSimulator|sensorTransPublisher|vehicleTransPublisher|terrainAnalysis|terrainAnalysisExt|sensorScanGeneration'
```

关键发现：

- 有一批 `16:37` 启动的旧进程仍然活着：
  - `vehicleSimulator`
  - `terrainAnalysis`
  - `terrainAnalysisExt`
  - `vehicleTransPublisher`
  - `sensorTransPublisher`
- 同时还有当前新会话的一批对应进程

结论：

- 老会话没有被 stop 脚本完全清干净
- 旧 `vehicleSimulator` 仍然在向当前 Gazebo 的 `/set_entity_state` 写入 `robot/lidar/camera`
- 于是新旧两套状态在“抢同一台车”

#### 步骤 27：修复 stop / launch 脚本

修改文件：

- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/stop_official_ariadne.sh`
- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch_official_ariadne.sh`

修复点：

- `stop_official_ariadne.sh` 新增清理：
  - `vehicleSimulator`
  - `sensorScanGeneration`
  - `terrainAnalysis`
  - `terrainAnalysisExt`
  - `static_transform_publisher /sensor->vehicle`
  - `static_transform_publisher /sensor->camera`
  - `robot_state_publisher`
  - `gzclient`
- `launch_official_ariadne.sh` 新增 stale-process 预检查：
  - 即使 `pids.env` 不存在，只要发现官方系统残留进程，也会拒绝启动并提示先 stop

#### 步骤 28：修复后的回归验证

先清场：

```bash
/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/stop_official_ariadne.sh
```

验证清理结果：

```bash
ps -ef | rg 'vehicleSimulator|sensorTransPublisher|vehicleTransPublisher|terrainAnalysis|terrainAnalysisExt|sensorScanGeneration|robot_state_publisher|gzserver|gzclient'
```

结果：

- 不再有匹配进程

重新启动后再次检查：

```bash
ros2 node list --no-daemon
ros2 topic info /state_estimation -v
```

关键结果：

- 图中只剩一个 `/vehicleSimulator`
- `/state_estimation`：
  - `Publisher count: 1`

再次采样 `/state_estimation`：

- 共收到 `301` 条 odom
- 最大相邻位姿跳变约 `0.01 m`

关键结果：

```text
max_step ... dt=0.00506 s, ds=0.01000 m
```

结论：

- 跳点问题已消失
- 之前的 A/B 闪现和悬浮，根因是旧会话残留导致的双 `vehicleSimulator` 竞争

#### 步骤 29：修复后同步快照验证 Gazebo 实体是否对齐

用一个临时 `rclpy` 节点同步读取：

- `/state_estimation`
- `/get_entity_state(robot)`
- `/get_entity_state(lidar)`
- `/get_entity_state(camera)`

关键结果：

```text
odom   14.6703 45.2205 0.7065
robot  14.6703 45.2205 0.7064
lidar  14.6703 45.2205 0.7064
camera 14.6703 45.2205 0.7056
```

结论：

- 清理残留后，`robot / lidar / camera / odom` 已重新对齐
- 当前主要异常已经修复

#### 步骤 30：修复 `Ctrl-C` 只关 GUI、不退出终端的问题

现场现象：

- 用户在启动终端按 `Ctrl-C` 后：
  - RViz 和 Gazebo 窗口会关闭
  - 但终端里的脚本没有完全退出

原因定位：

启动脚本里原先是：

```bash
trap cleanup EXIT INT TERM
```

而 `cleanup()` 只做：

- kill 子进程
- 删除 pid 文件

没有执行：

- `exit`

因此在用户按 `Ctrl-C` 时：

- 子进程确实被清掉了
- 但顶层 bash 会回到脚本最后的：

```bash
while true; do
  sleep 2
done
```

看起来就像“GUI 停了，但终端没停”。

处理：

- 修改：
  - `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch_official_ariadne.sh`
- 拆分为：
  - `trap cleanup EXIT`
  - `trap 'handle_signal 130' INT`
  - `trap 'handle_signal 143' TERM`
- `handle_signal()` 会：
  - 先清理
  - 再显式 `exit`

回归验证：

1. 启动一轮 headless 会话
2. 向会话发送一次 `Ctrl-C`

结果：

- 会话直接以 `exit code 130` 退出
- 不再残留“GUI 已关但终端还挂着”的问题

确认存在：

- `ros-humble-gazebo-dev`
- `ros-humble-gazebo-msgs`
- `ros-humble-gazebo-plugins`
- `ros-humble-gazebo-ros`
- `ros-humble-gazebo-ros2-control`
- `ros-humble-gazebo-ros-pkgs`
- `gazebo`
- `libgazebo-dev`

#### 步骤 9：尝试安装缺失系统依赖

命令：

```bash
sudo apt install -y \
  gazebo \
  libgazebo-dev \
  ros-humble-gazebo-dev \
  ros-humble-gazebo-msgs \
  ros-humble-gazebo-plugins \
  ros-humble-gazebo-ros \
  ros-humble-gazebo-ros2-control \
  ros-humble-gazebo-ros-pkgs
```

结果：

- 失败。

报错：

```text
sudo: a terminal is required to read the password; either use the -S option to read from standard input or configure an askpass helper
sudo: a password is required
```

问题：

- 当前环境没有无密码 sudo。
- 因此我无法直接代替用户完成系统级 apt 安装。

结论：

- 这是当前主阻塞。
- 在用户手动完成 apt 安装前，官方 Gazebo 工作区无法完成编译，也无法继续实际启动 Gazebo 仿真。

#### 步骤 10：继续完成无 sudo 阶段可做的自动化准备

目的：

- 把后续复现和接入动作固化成脚本。
- 一旦用户手动补齐系统依赖，可直接继续。

新增脚本：

- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/link_official_env_models.sh`
- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/build_official_dev_env.sh`
- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch_official_ariadne.sh`

对应作用：

- `link_official_env_models.sh`
  - 幂等地把下载好的 5 个环境目录软链接到官方仓库 `src/vehicle_simulator/mesh/`
- `build_official_dev_env.sh`
  - 以官方推荐命令构建工作区
- `launch_official_ariadne.sh`
  - 在官方系统之上启动 `octomap_server + rl_planner`
  - 默认采用 `BASE_FRAME=sensor`

为什么这里默认 `sensor`：

- 官方 `vehicleSimulator.cpp` 发布 `/state_estimation`，其 `child_frame_id = "sensor"`
- 官方 `sensorScanGeneration.cpp` 生成：
  - `/state_estimation_at_scan`，`child_frame_id = "sensor_at_scan"`
  - `/sensor_scan`，`frame_id = "sensor_at_scan"`
- 两个 frame 都挂在 `map` 下，因此 `octomap_server` 使用 `base_frame_id=sensor` 在官方栈里是成立的。
- 这和当前 Unity 衍生栈不同；Unity 那边为了适配现有 relay / frame 约束，更稳妥的是用 `sensor_at_scan`。

对脚本的即时验证：

命令：

```bash
/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/link_official_env_models.sh
```

结果：

- 成功。
- 输出全部为 `OK: ... -> ...`

脚本语法检查：

```bash
bash -n \
  /home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/link_official_env_models.sh \
  /home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/build_official_dev_env.sh \
  /home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch_official_ariadne.sh
```

结果：

- 成功，无 shell 语法错误。

#### 步骤 11：迁移官方仓库到正式路径

用户要求：

- 不再放在：
  - `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/tmp/autonomous_exploration_development_environment`
- 改为正式位置：
  - `/home/liuyi/projects/thermal_nav/autonomous_exploration_development_environment`

迁移前检查：

```bash
ls -ld /home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/tmp/autonomous_exploration_development_environment
ls -ld /home/liuyi/projects/thermal_nav/autonomous_exploration_development_environment || true
```

结果：

- 源目录存在。
- 目标目录不存在，因此可安全迁移。

迁移命令：

```bash
mv /home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/tmp/autonomous_exploration_development_environment \
   /home/liuyi/projects/thermal_nav/autonomous_exploration_development_environment
```

结果：

- 成功。

迁移后验证：

```bash
ls -ld /home/liuyi/projects/thermal_nav/autonomous_exploration_development_environment
```

结果：

- 目标目录存在，迁移成功。

#### 步骤 12：修正辅助脚本默认路径

受影响脚本：

- `scripts/gazebo/link_official_env_models.sh`
- `scripts/gazebo/build_official_dev_env.sh`
- `scripts/gazebo/launch_official_ariadne.sh`

修改内容：

- 默认 `OFFICIAL_ENV_DIR` 从旧路径：
  - `${ROOT_DIR}/tmp/autonomous_exploration_development_environment`
- 改为热导航目录下的正式路径：
  - `$(dirname "${ROOT_DIR}")/autonomous_exploration_development_environment`

修改后验证：

```bash
bash -n \
  /home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/link_official_env_models.sh \
  /home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/build_official_dev_env.sh \
  /home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch_official_ariadne.sh
```

- 成功，无 shell 语法错误。

进一步验证模型链接脚本：

```bash
/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/link_official_env_models.sh
```

结果：

- 成功。
- 已输出新的正式路径下 `mesh/*` 的 `OK: ... -> ...` 记录。

## 3. 当前阻塞总结

- 主阻塞只有一个：
  - 缺少 root 权限完成 apt 安装

未阻塞部分：

- 官方仓库已拉取
- `humble` 分支已确认
- 模型路径已接通
- 官方/ARiADNE 话题接口已核对
- 后续复现脚本已落地

## 4. 用户需要补的一步

用户需在本机执行一次：

```bash
sudo apt install -y \
  gazebo \
  libgazebo-dev \
  ros-humble-gazebo-dev \
  ros-humble-gazebo-msgs \
  ros-humble-gazebo-plugins \
  ros-humble-gazebo-ros \
  ros-humble-gazebo-ros2-control \
  ros-humble-gazebo-ros-pkgs
```

完成后，本日志对应的下一步应为：

```bash
cd /home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/tmp/autonomous_exploration_development_environment
set +u && source /opt/ros/humble/setup.bash && \
colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release
```

## 5. 用户安装 Gazebo 依赖后继续执行

用户已在本机手动执行：

```bash
sudo apt install -y \
  gazebo \
  libgazebo-dev \
  ros-humble-gazebo-dev \
  ros-humble-gazebo-msgs \
  ros-humble-gazebo-plugins \
  ros-humble-gazebo-ros \
  ros-humble-gazebo-ros2-control \
  ros-humble-gazebo-ros-pkgs
```

结论：

- 依赖安装完成后，可以继续编译和运行官方工作区。

## 6. 迁移后的首次编译与修复

### 6.1 迁移后直接编译失败

命令：

```bash
cd /home/liuyi/projects/thermal_nav/autonomous_exploration_development_environment
set +u && source /opt/ros/humble/setup.bash && \
colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release
```

问题：

- 由于仓库从 `tmp/` 迁移到了正式目录，旧 `build/` 目录里的 CMake 缓存仍然指向原路径，导致编译失败。

处理：

```bash
rm -rf /home/liuyi/projects/thermal_nav/autonomous_exploration_development_environment/build \
       /home/liuyi/projects/thermal_nav/autonomous_exploration_development_environment/install \
       /home/liuyi/projects/thermal_nav/autonomous_exploration_development_environment/log
```

### 6.2 清理后重新编译

命令：

```bash
cd /home/liuyi/projects/thermal_nav/autonomous_exploration_development_environment
set +u && source /opt/ros/humble/setup.bash && \
colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release
```

结果：

- 成功。
- 官方工作区完成编译。

## 7. 首次官方 Gazebo 启动遇到的问题

### 7.1 官方原始 launch 依赖 `xacro`

命令：

```bash
set +u && source /opt/ros/humble/setup.bash && \
source /home/liuyi/projects/thermal_nav/autonomous_exploration_development_environment/install/setup.bash && \
ros2 launch vehicle_simulator system_garage.launch gazebo_gui:=false
```

问题：

- 当前机器没有 `xacro`，官方 `vehicle_simulator.launch` 直接失败。

处理策略：

- 不再继续追系统级安装。
- 在当前仓库中补一套“不依赖 xacro”的 wrapper launch。

新增文件：

- `scripts/gazebo/assets/vlp16_lidar.urdf`
- `scripts/gazebo/assets/camera.urdf`
- `scripts/gazebo/launch/official_vehicle_simulator_no_xacro.launch.py`
- `scripts/gazebo/launch/official_system_no_xacro.launch.py`

### 7.2 沙箱运行 Gazebo 时暴露的额外问题

首次用 wrapper 启动后，出现以下问题：

- DDS/UDP 权限错误
- `spawn_entity.py` 报 `ModuleNotFoundError: No module named 'lxml'`
- `visualization_tools` 受用户 Python 环境污染，触发 `matplotlib/numpy` 兼容问题
- `gzserver` 试图写入 `~/.gazebo`，在沙箱里失败

处理：

- 改为在沙箱外运行 Gazebo
- 固定运行环境：

```bash
export GAZEBO_HOME=/tmp/gazebo_home
export ROS_LOG_DIR=/tmp/roslogs_official_garage_noxacro3
export PYTHONNOUSERSITE=1
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/ros/humble/bin:$PATH
```

- `official_system_no_xacro.launch.py` 中移除 `visualization_tools`
- 继续使用 headless 方式验证核心链路

## 8. Gazebo 实体生成时序问题与修复

### 8.1 问题现象

第一次 wrapper 版系统虽然起了 `/gazebo`，但 3 个实体没有真的生成：

- `lidar`
- `robot`
- `camera`

证据：

- 早期 `spawn_entity.py` 日志显示：
  - `Service /spawn_entity unavailable. Was Gazebo started with GazeboRosFactory?`
- 随后 `gazebo_ros_state` 持续报：
  - `entity [camera] does not exist`
  - `entity [robot] does not exist`
  - `entity [lidar] does not exist`

根因：

- 不是 `gazebo_ros_factory` 永久缺失。
- 而是 world 加载较慢，`/spawn_entity` 服务可用前，3 个 `spawn_entity.py` 已经超时退出。

### 8.2 修复动作

新增脚本：

- `scripts/gazebo/spawn_entity_when_ready.sh`

作用：

- 轮询 `/spawn_entity`
- 服务就绪后再执行 `/opt/ros/humble/lib/gazebo_ros/spawn_entity.py`

同时修改：

- `scripts/gazebo/launch/official_vehicle_simulator_no_xacro.launch.py`

修改内容：

- 不再并发直接 spawn
- 改为串行：
  1. `lidar`
  2. `robot`
  3. `camera`
  4. 最后再启动 `vehicleSimulator`

结果：

- `SpawnEntity: Successfully spawned entity [lidar]`
- `SpawnEntity: Successfully spawned entity [robot]`
- `SpawnEntity: Successfully spawned entity [camera]`

## 9. 官方 Gazebo 主链验证通过

验证命令示例：

```bash
export PYTHONNOUSERSITE=1
set +u
source /opt/ros/humble/setup.bash
source /home/liuyi/projects/thermal_nav/autonomous_exploration_development_environment/install/setup.bash
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/ros/humble/bin:$PATH
ros2 node list
ros2 service list
timeout 8 ros2 topic echo --once /model_states
timeout 8 ros2 topic echo --once /sensor_scan
timeout 8 ros2 topic echo --once /terrain_map
```

确认结果：

- `/gazebo`
- `/localPlanner`
- `/pathFollower`
- `/terrainAnalysis`
- `/terrainAnalysisExt`
- `/sensorScanGeneration`
- `/vehicleSimulator`
- `/velodyne/gazebo_ros_laser_controller`
- `/camera_controller`

关键 topic 已有数据：

- `/model_states`
- `/state_estimation`
- `/sensor_scan`
- `/terrain_map`

结论：

- 官方 Gazebo ROS2 Humble 主链已经在本机跑通。

## 10. ARiADNE 接入时遇到的问题

### 10.1 `rl_planner` 缺少 `matplotlib`

首次直接接入命令：

```bash
export START_SYSTEM=0
export START_RVIZ=0
export SCENE=garage
/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch_official_ariadne.sh
```

问题：

- `/octomap_server` 正常
- `rl_planner` 启动后很快退出

前台单独复现后得到真实报错：

```text
ModuleNotFoundError: No module named 'matplotlib'
```

### 10.2 Python 依赖分裂

进一步核对发现：

- `ros2-torch` conda 环境中有：
  - `torch`
  - `numpy`
- 但最初没有可靠带出 ROS Python 依赖
- 更关键的是：
  - `matplotlib` 实际安装在用户 site：
    - `/home/liuyi/.local/lib/python3.10/site-packages/matplotlib`
  - 并不在 `ros2-torch` 环境自带 site-packages 中

这导致：

- 系统阶段需要 `PYTHONNOUSERSITE=1` 来避免 Gazebo/ROS 被用户站点污染
- ARiADNE 阶段反而必须允许用户 site，才能找到当前这份 `matplotlib`

### 10.3 全局 `LD_PRELOAD` 干扰 conda

最初曾把：

```bash
LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libstdc++.so.6
```

挂成全局变量，结果触发：

```text
Error while loading conda entry point: conda-libmamba-solver ...
GLIBCXX_3.4.31 not found
```

处理：

- 移除 `launch_official_ariadne.sh` 中的全局 `LD_PRELOAD`

### 10.4 无 TTY 场景下 `ros2 run rl_planner` 的可用性问题

进一步实测发现：

- 在前台 TTY 环境下，`rl_planner` 可以跑起来
- 在无 TTY 或后台模式下，如果同时保留 `PYTHONNOUSERSITE=1`，就会再次出现 `matplotlib` 缺失

最终处理方案：

- `launch_official_ariadne.sh` 分两段环境运行：
  - 官方系统阶段：
    - 保留 `PYTHONNOUSERSITE=1`
  - ARiADNE 阶段：
    - `source /opt/ros/humble/setup.bash`
    - `source /home/liuyi/miniforge3/etc/profile.d/conda.sh`
    - `conda activate ros2-torch`
    - 再 `source` 两个工作区
    - `unset PYTHONNOUSERSITE`
    - 放开用户 site，让当前 `matplotlib` 可见

为此修改了：

- `scripts/gazebo/launch_official_ariadne.sh`

## 11. `garage` 集成结论

在 `garage` 中，接入已经成立：

- `/rl_planner` 能起
- `/octomap_server` 能起
- `/projected_map` 能出

但行为上验证了早先判断：

- `exploration_finish` 很快变成 `true`
- `/way_point` 后续无稳定新输出

结论：

- `garage` 更适合验证官方 Gazebo 系统链是否通
- 不适合作为 ARiADNE 首个有效联调场景

## 12. `indoor` 场景完整联调成功

完整启动命令：

```bash
export START_SYSTEM=1
export START_RVIZ=0
export SCENE=indoor
export GAZEBO_GUI=false
/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch_official_ariadne.sh
```

启动结果：

- 官方系统启动成功
- `indoor.world` 已加载
- `/sensor_scan`、`/projected_map` 正常
- `octomap_server` 正常
- `rl_planner` 正常

验证命令：

```bash
export PYTHONNOUSERSITE=1
set +u
source /opt/ros/humble/setup.bash
source /home/liuyi/projects/thermal_nav/autonomous_exploration_development_environment/install/setup.bash
source /home/liuyi/projects/thermal_nav/ARiADNE-ROS-Planner/install/setup.bash
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/ros/humble/bin:$PATH
ros2 node list
timeout 8 ros2 topic echo --once /exploration_finish
timeout 8 ros2 topic echo --once /way_point
```

验证结果：

- 节点图中存在：
  - `/rl_planner`
  - `/octomap_server`
- `exploration_finish` 当前为：

```text
data: false
```

- `way_point` 当前已成功输出，例如：

```text
point:
  x: 18.0
  y: 40.0
  z: 0.0
```

结论：

- 官方 Gazebo ROS2 Humble 流程已经在 `indoor` 场景跑通
- 下载的环境模型已接入
- `ARiADNE-ROS-Planner` 已成功接入官方 Gazebo 线

## 13. 后续修复：把 `matplotlib` 真正装进 `ros2-torch`

### 13.1 修复前状态核对

核对命令：

```bash
set +u
source /home/liuyi/miniforge3/etc/profile.d/conda.sh
conda activate ros2-torch
python - <<'PY'
import site
mods=['torch','torchvision','matplotlib','skimage','rospkg']
for m in mods:
    mod=__import__(m)
    print(m, getattr(mod, '__file__', None))
print('USER_SITE', site.getusersitepackages())
PY
```

关键发现：

- `torch`、`torchvision`、`skimage`、`rospkg` 已位于：
  - `/home/liuyi/miniforge3/envs/ros2-torch/lib/python3.10/site-packages`
- 但 `matplotlib` 位于：
  - `/home/liuyi/.local/lib/python3.10/site-packages/matplotlib`

进一步验证：

```bash
set +u
source /opt/ros/humble/setup.bash
source /home/liuyi/miniforge3/etc/profile.d/conda.sh
conda activate ros2-torch
export PYTHONNOUSERSITE=1
python - <<'PY'
mods=['torch','torchvision','matplotlib','skimage','rospkg','rclpy','sensor_msgs_py']
for m in mods:
    try:
        mod=__import__(m)
        print(m, getattr(mod, '__file__', None))
    except Exception as e:
        print(m, 'FAIL', e)
PY
```

结果：

- `torch`、`torchvision`、`skimage`、`rospkg`、`rclpy`、`sensor_msgs_py` 均可导入
- 只有 `matplotlib` 失败：
  - `FAIL No module named 'matplotlib'`

结论：

- 当时真正缺的只有 `matplotlib`
- ARiADNE 之所以依赖 user-site，是因为这一个包没有装进 `ros2-torch`

### 13.2 安装到 conda 环境本体

执行命令：

```bash
set +u
source /home/liuyi/miniforge3/etc/profile.d/conda.sh
conda activate ros2-torch
python -m pip install --force-reinstall --no-user matplotlib
```

结果：

- 成功
- 实际安装版本：
  - `matplotlib 3.10.8`

安装完成后确认：

```bash
set +u
source /home/liuyi/miniforge3/etc/profile.d/conda.sh
conda activate ros2-torch
python -m pip show matplotlib
```

关键结果：

- `Location: /home/liuyi/miniforge3/envs/ros2-torch/lib/python3.10/site-packages`

同时验证用户 site：

```bash
find /home/liuyi/.local/lib/python3.10/site-packages -maxdepth 1 \
  \( -name 'matplotlib' -o -name 'matplotlib-*.dist-info' \) | sort
```

结果：

- 该用户 site 目录已不存在

### 13.3 安装后验证 `PYTHONNOUSERSITE=1`

验证命令：

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

结果：

- `matplotlib`、`skimage`、`rospkg` 均来自 `ros2-torch`
- `rclpy`、`sensor_msgs_py` 仍来自 ROS2 Humble

结论：

- 现在即使禁用 user-site，也能满足 ARiADNE 运行依赖

## 14. 移除对 user-site 的脚本依赖

修改文件：

- `scripts/gazebo/launch_official_ariadne.sh`

修改前：

- `activate_ariadne_env()` 中会：
  - `unset PYTHONNOUSERSITE`
  - 打印 `Enabled user-site Python packages for ARiADNE runtime`

修改后：

- 不再 `unset PYTHONNOUSERSITE`
- 全流程保持 `PYTHONNOUSERSITE=1`
- 不再依赖用户 site Python 包

验证：

```bash
bash -n /home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch_official_ariadne.sh
```

结果：

- 成功，无语法错误

## 15. 去掉 user-site 依赖后的回归验证

### 15.1 清理重复测试进程

由于前面多次回归验证，出现了重复的：

- `/octomap_server`
- `/rl_planner`

已清理多余进程，保留单组运行实例。

### 15.2 最终回归

执行命令：

```bash
export START_SYSTEM=1
export START_RVIZ=0
export SCENE=indoor
export GAZEBO_GUI=false
/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch_official_ariadne.sh
```

结果：

- `Topic ready: /state_estimation`
- `Topic ready: /sensor_scan`
- `Activated conda env: ros2-torch`
- `octomap started`
- `Topic ready: /projected_map`
- `rl_planner started`
- `Topic ready: /way_point`

进一步验证命令：

```bash
export PYTHONNOUSERSITE=1
set +u
source /opt/ros/humble/setup.bash
source /home/liuyi/projects/thermal_nav/autonomous_exploration_development_environment/install/setup.bash
source /home/liuyi/projects/thermal_nav/ARiADNE-ROS-Planner/install/setup.bash
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/ros/humble/bin:$PATH
ros2 node list
```

最终节点结果：

- `/octomap_server`
- `/rl_planner`

进程结果：

- `octomap_server_node` 仅保留一组
- `rl_planner` 仅保留一组
- `rl_planner` 实际由：
  - `/home/liuyi/miniforge3/envs/ros2-torch/bin/python`
 运行

最终结论：

- `matplotlib` 已经真正安装到 `ros2-torch`
- `launch_official_ariadne.sh` 已去掉对 user-site 的依赖
- 当前官方 Gazebo + ARiADNE `indoor` 流程仍然可以正常运行

## 16. 文档整理与正式使用流收敛

### 16.1 新增对照文档

新增：

- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/docs_liuyi/codex/unity_vs_official_gazebo_ros2_diff_20260328.md`

内容：

- Unity 线与官方 Gazebo ROS2 线的结构差异
- 启动链差异
- 话题/TF 差异
- 运行环境差异
- 场景建议
- 迁移判断

### 16.2 新增正式使用说明

新增：

- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/docs_liuyi/codex/official_gazebo_ros2_usage_guide_20260328.md`

内容：

- 当前推荐脚本
- 一次性准备
- 启动与停止
- 场景建议
- 验证命令
- 常见问题

## 17. Gazebo 线补充 stop 脚本

新增：

- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/stop_official_ariadne.sh`

同时更新：

- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch_official_ariadne.sh`

收敛后的能力：

- 启动脚本会写 pid 文件
- 停止脚本优先走 pid 文件模式
- 如果 pid 文件不存在，则自动退回到进程模式清理旧会话

pid 文件位置：

- `/home/liuyi/projects/thermal_nav/ARiADNE-ROS-Planner/tmp/official_gazebo_ariadne_run/pids.env`

## 18. stop 脚本验证

### 18.1 pid 文件模式验证

启动新会话后检查：

```bash
cat /home/liuyi/projects/thermal_nav/ARiADNE-ROS-Planner/tmp/official_gazebo_ariadne_run/pids.env
```

结果示例：

```text
SYSTEM_PID=99566
OCTOMAP_PID=99792
RL_PLANNER_PID=99853
RVIZ_PID=
```

随后执行：

```bash
/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/stop_official_ariadne.sh
```

结果：

- 能识别并停止：
  - `RL_PLANNER_PID`
  - `OCTOMAP_PID`
  - `SYSTEM_PID`

### 18.2 fallback 模式验证

在 pid 文件缺失但残留进程仍存在的情况下，执行：

```bash
/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/stop_official_ariadne.sh
```

结果：

- 输出：

```text
No pid file found ...
Falling back to process-pattern shutdown
Stopped official Gazebo + ARiADNE session (fallback mode)
```

- 最终再次检查：

```bash
ps -ef | rg 'official_system_no_xacro.launch.py|gzserver .*vehicle_simulator/world/|octomap_server_node|ros2 run rl_planner rl_planner|install/rl_planner/lib/rl_planner/rl_planner'
```

- 不再有匹配的 Gazebo/ARiADNE 进程残留

结论：

- 当前 Gazebo 线已经具备：
  - 文档
  - 启动脚本
  - 停止脚本
  - 依赖固化
  - 运行验证
