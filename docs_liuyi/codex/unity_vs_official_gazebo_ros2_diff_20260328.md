# Unity vs Official Gazebo ROS2 流程差异整理

日期：2026-03-28

范围：

- Unity 线：
  - `/home/liuyi/projects/thermal_nav/autonomy_stack_mecanum_wheel_platform`
  - `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/launch_unity_ariadne.sh`
- 官方 Gazebo ROS2 线：
  - `/home/liuyi/projects/thermal_nav/autonomous_exploration_development_environment`
  - `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch_official_ariadne.sh`

## 1. 一句话结论

- Unity 线更像“你当前工程化集成后的派生链”。
- 官方 Gazebo ROS2 线更像“CMU 原生开发环境 + ARiADNE 原生接口链”。
- 如果目标是做可复现实验、减少桥接层和接口补丁，官方 Gazebo ROS2 线应作为主线。

## 2. 依赖结构差异

| 维度 | Unity 线 | 官方 Gazebo ROS2 线 |
| --- | --- | --- |
| 仓库主体 | `autonomy_stack_mecanum_wheel_platform` | `autonomous_exploration_development_environment` |
| 仿真内核 | Unity 可执行文件 | Gazebo + `gazebo_ros` |
| ROS 桥接 | `ros_tcp_endpoint` 必需 | 不需要 ROS-TCP 桥 |
| 环境模型来源 | Unity 打包环境 | `autonomous_exploration_environments` 模型目录 |
| ROS2 Gazebo 依赖 | 相对少 | 依赖 `gazebo`、`ros-humble-gazebo-*` |
| ARiADNE 运行环境 | ROS2 工作区 + 当前本机依赖 | ROS2 工作区 + `ros2-torch` conda 环境 |

核心区别：

- Unity 线必须先起 Unity 二进制，再起 ROS 仿真，再起 ROS-TCP endpoint。
- Gazebo 线直接由 ROS2 launch 把 world、robot、sensor、planner 链拉起来。

## 3. 启动链差异

### 3.1 Unity 线

主脚本：

- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/launch_unity_ariadne.sh`

实际顺序：

1. 启动 Unity 可执行文件
2. 启动 `vehicle_simulator system_simulation.launch`
3. 重启 `ros_tcp_endpoint`
4. 等待 `/state_estimation`、`/sensor_scan`
5. 启动 `octomap_server`
6. 启动 `rl_planner`
7. 发布 `/joy` 的 Resume Navigation 消息

特点：

- 多一个“Resume Navigation”控制动作
- 多一个 ROS-TCP 桥
- 强依赖 Unity 可执行文件和其运行状态

### 3.2 官方 Gazebo ROS2 线

主脚本：

- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch_official_ariadne.sh`

实际顺序：

1. 可选启动官方系统
2. 等待 `/state_estimation`、`/sensor_scan`
3. 激活 `ros2-torch`
4. 启动 `octomap_server`
5. 等待 `/projected_map`
6. 启动 `rl_planner`

特点：

- 没有 Unity 进程
- 没有 ROS-TCP endpoint
- 没有 `/joy` Resume Navigation 这一步
- 拓扑更接近 ARiADNE README 里的原始运行方式

## 4. 启停管理差异

### 4.1 Unity 线

已有：

- 启动：
  - `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/launch_unity_ariadne.sh`
- 停止：
  - `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/stop_unity_ariadne.sh`

机制：

- 使用 pid 文件
- 能较稳定地清理 Unity、ROS launch、endpoint、octomap、planner、RViz

### 4.2 Gazebo 线

现已补齐：

- 启动：
  - `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch_official_ariadne.sh`
- 停止：
  - `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/stop_official_ariadne.sh`

机制：

- 同样使用 pid 文件
- pid 文件默认路径：
  - `/home/liuyi/projects/thermal_nav/ARiADNE-ROS-Planner/tmp/official_gazebo_ariadne_run/pids.env`

结论：

- 现在两条线都具备“脚本启动 + 脚本停止”的基本工程形态。

## 5. 话题与 TF 差异

### 5.1 两条线共同依赖的核心接口

ARiADNE 实际只依赖一小层接口：

- 输入：
  - `/state_estimation`
  - `/sensor_scan`
  - `/projected_map`
- 输出：
  - `/way_point`
  - `/exploration_finish`

这也是两条线都能接 ARiADNE 的根本原因。

### 5.2 Unity 线的特殊点

- 当前 Unity 集成里，`octomap_server` 使用：
  - `base_frame_id:=sensor_at_scan`
- 这是现有 Unity 集成为了配合其 scan/TF 链做的选择。

### 5.3 官方 Gazebo 线的特殊点

- 当前官方 Gazebo 线验证通过的配置使用：
  - `base_frame_id:=sensor`
- 官方环境仍然发布：
  - `/state_estimation_at_scan`
  - `/sensor_scan` 的 `frame_id=sensor_at_scan`
- 但在当前实测里，以 `sensor` 作为 octomap base frame 可以跑通。

结论：

- Unity 线更像“按现有集成补丁适配后的 frame 方案”
- Gazebo 线更接近官方原始语义

## 6. Python/运行时环境差异

### 6.1 Unity 线

- 主要跑在当前 ROS2 系统环境上
- 当前脚本没有显式切换到 `ros2-torch`

### 6.2 Gazebo 线

- 系统阶段：
  - 使用系统 ROS2 Humble 环境
  - 保持 `PYTHONNOUSERSITE=1`
- ARiADNE 阶段：
  - 激活 `ros2-torch`
  - 再 source ROS2 和两个工作区

最新状态：

- `matplotlib` 已正式安装到 `ros2-torch`
- 已经不再依赖 user-site

这意味着：

- Gazebo 线现在比之前更稳
- 其环境隔离也比之前更清晰

## 7. 当前使用的 launch 差异

### 7.1 Unity 线

- 直接使用现有 autonomy stack 的系统 launch

### 7.2 Gazebo 线

当前推荐使用的是本地 wrapper，而不是官方原始 launch：

- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch/official_system_no_xacro.launch.py`
- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch/official_vehicle_simulator_no_xacro.launch.py`

原因：

- 这台机器当前没有 `xacro`
- wrapper 已经绕过 `xacro`
- wrapper 还修复了 `spawn_entity` 的时序问题
- wrapper 现在还显式接通了 `Gazebo GUI`
- wrapper 为 Gazebo 线补了一套 clean RViz 默认配置
- wrapper 还绕开了当前机器 `snap` 环境对 `rviz2` 的污染

结论：

- 当前 Gazebo 主线是“官方环境 + 本地稳定性 wrapper”
- 不是未经修正的官方原始 launch

## 8. 评测与统计口径差异

### 8.1 Unity 线

- 现有监控链更偏 wall-clock
- 例如你当前实验监控脚本依赖真实时间

### 8.2 Gazebo 线

- Gazebo/ROS2 栈天然更接近 sim time
- `/clock` 可直接用于标准化统计

结论：

- 如果后续要做 Unity vs Gazebo 的结果对比，必须统一：
  - 时间基准
  - 完成判据
  - 场景选择

否则直接对比会有口径偏差。

## 9. 场景适用性差异

### 9.1 `garage`

用途：

- 更适合做 Gazebo 主链 smoke test
- 不适合作为 ARiADNE 首个有效联调场景

实测现象：

- `garage` 上 ARiADNE 很容易快速进入：
  - `exploration_finish=true`

### 9.2 `indoor`

用途：

- 当前最佳首测场景
- 适合作为官方 Gazebo + ARiADNE 的标准联调入口

实测现象：

- `/rl_planner` 正常
- `/way_point` 正常
- `exploration_finish=false`

结论：

- Unity vs Gazebo 的首轮对照，建议统一先用“结构最接近 indoor 的场景”

## 10. 工程复杂度对比

### 10.1 Unity 线复杂度来源

- Unity 可执行文件本身
- ROS-TCP endpoint
- Resume Navigation 额外控制
- 现有 frame/relay 适配历史

### 10.2 Gazebo 线复杂度来源

- Gazebo ROS 依赖安装
- 官方 repo 编译
- `xacro` 缺失时需要 wrapper
- ARiADNE 依赖需要落到 `ros2-torch`

判断：

- Unity 线复杂度更偏“多进程桥接复杂度”
- Gazebo 线复杂度更偏“环境和依赖治理复杂度”

一旦依赖稳定后，Gazebo 线的长期维护成本更低。

## 11. 对 ARiADNE 接入的影响

### 11.1 Unity 线

- 已经证明 ARiADNE 可接
- 但依赖更多桥接和补丁

### 11.2 Gazebo 线

- 现在也已证明 ARiADNE 可接
- 并且接口面更贴近 ARiADNE 原生预期

判断：

- 如果目标是“复现实验”和“最小偏离官方环境”，优先 Gazebo
- 如果目标是“延续你现在已有 Unity 数据链”，Unity 仍有价值，但更适合作为对照组

## 12. 迁移建议

建议按下面方式使用两条线：

1. 把官方 Gazebo ROS2 线作为主开发/主验证线。
2. 把 Unity 线保留为历史对照线，不再作为接口设计基准。
3. ARiADNE 相关参数优先在 `indoor` 上调好，再迁移到其他场景。
4. 做对照实验时，不要拿 `garage` 当主对照场景。
5. 对外或对论文复现实验，优先描述 Gazebo 线。

## 13. 当前推荐结论

当前这台机器上，推荐主线是：

1. 官方 Gazebo ROS2 Humble 环境
2. `indoor` 场景
3. `ros2-torch` 中运行 ARiADNE
4. 使用：
   - `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch_official_ariadne.sh`
   - `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/stop_official_ariadne.sh`

Unity 线建议保留，但定位改为：

- 已有工程链参考
- 对照实验链
- 非主开发链
