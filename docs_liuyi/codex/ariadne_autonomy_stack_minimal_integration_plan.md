# ARiADNE 接入 autonomy_stack 的最小改造方案

**目标系统**：`/home/liuyi/projects/thermal_nav/autonomy_stack_mecanum_wheel_platform`  
**目标仓库**：`ARiADNE-ROS-Planner` `humble` 分支  
**目标原则**：尽量不动现有底层导航与感知，只替换探索 waypoint 生成器。

---

## 1. 先给出最终结论

将 ARiADNE 接进你当前 `autonomy_stack` 的最小改造方案是可行的，而且边界比较清楚：

- **保留**：`FAST-LIO2`、`registered_scan_frame_relay`、`odom_frame_relay`、`sensor_scan_generation`、`terrain_analysis`、`localPlanner`、`pathFollower`
- **删除/停用**：`tare_planner_node`
- **新增**：`octomap_server_node` + `rl_planner`
- **不变的核心接口**：`/way_point`

一句话概括就是：

> 把当前系统中 “TARE -> /way_point” 这一段，替换为 “octomap_server -> /projected_map -> ARiADNE rl_planner -> /way_point”。

---

## 2. 为什么这个方案叫“最小改造”

因为它满足三条最关键的约束。

### 2.1 不重写 local planner

你当前 `localPlanner` 已经能吃：

- `/state_estimation`
- `/registered_scan`
- `/terrain_map`
- `/way_point`

其中 `/way_point` 是唯一与高层探索器直接耦合的输入。

所以只要新探索器仍发布同样的 `geometry_msgs/PointStamped /way_point`，下游可以保持不变。

### 2.2 不重写 SLAM / scan relay

你当前链路已经稳定产出：

- `/state_estimation`
- `/registered_scan`
- `/sensor_scan`

而 ARiADNE 正好需要：

- `/state_estimation`
- `/sensor_scan`

这说明你已经有了它需要的大部分上游数据。

### 2.3 不要求立即重训练

`ARiADNE-ROS-Planner` `humble` 分支自带 checkpoint，可先验证预训练模型是否方向正确。

---

## 3. 当前系统的数据流与目标数据流

### 3.1 当前 TARE 版本

```text
FAST-LIO2
  -> /state_estimation_raw + /registered_scan_raw
  -> odom_frame_relay + registered_scan_frame_relay
  -> /state_estimation + /registered_scan

/state_estimation + /registered_scan
  -> sensor_scan_generation
  -> /state_estimation_at_scan + /sensor_scan

/registered_scan
  -> terrain_analysis
  -> /terrain_map

/terrain_map + /terrain_map_ext + /state_estimation_at_scan + /registered_scan
  -> tare_planner_node
  -> /way_point

/way_point + /terrain_map + /registered_scan + /state_estimation
  -> localPlanner
  -> /path
  -> pathFollower
  -> /cmd_vel
```

### 3.2 目标 ARiADNE 版本

```text
FAST-LIO2
  -> /state_estimation_raw + /registered_scan_raw
  -> odom_frame_relay + registered_scan_frame_relay
  -> /state_estimation + /registered_scan

/state_estimation + /registered_scan
  -> sensor_scan_generation
  -> /state_estimation_at_scan + /sensor_scan

/registered_scan
  -> terrain_analysis
  -> /terrain_map

/sensor_scan
  -> octomap_server_node
  -> /projected_map

/projected_map + /state_estimation
  -> rl_planner
  -> /way_point

/way_point + /terrain_map + /registered_scan + /state_estimation
  -> localPlanner
  -> /path
  -> pathFollower
  -> /cmd_vel
```

从这个对比你可以看出：

- `terrain_analysis` 仍保留，服务 local planner
- `sensor_scan_generation` 仍保留，服务 ARiADNE 的 `octomap_server`
- `terrain_analysis_ext` 对 ARiADNE 本身不是必需

---

## 4. 需要新增和修改的最少内容

如果目标只是“最小可验证版本”，我建议只做下面四项。

### 4.1 新增一个独立的 ARiADNE 工作区或 overlay

不建议第一步就把 ARiADNE 代码直接混进你当前主工作区。

建议两种方式二选一。

#### 方式 A：独立工作区，验证后再并入

例如：

```text
/home/liuyi/projects/thermal_nav/ariadne_ros_ws
```

优点：

- 边界清晰
- 先验证包本身是否可用
- 不污染现有工作区

#### 方式 B：后续稳定后再 vendor 到当前工作区

例如放进：

```text
autonomy_stack_mecanum_wheel_platform/src/external/ariadne_ros_planner/
```

我建议先 A 后 B。

### 4.2 新建一个 launch 文件

建议在 `autonomy_stack` 里新增一个专门入口，比如：

```text
src/base_autonomy/vehicle_simulator/launch/system_scout_hesai_with_ariadne.launch.py
```

这个 launch 应当：

- 复制 `system_scout_hesai_with_tare.launch.py`
- 删除 `tare_planner_node`
- 删除 TARE 特有的 OR-Tools 环境变量注入
- 新增 `octomap_server_node`
- 新增 `rl_planner`

### 4.3 只保留 ARiADNE 必需的高层输入

ARiADNE 高层侧需要的最少输入是：

- `/sensor_scan`
- `/state_estimation`

因此高层替换时：

- `/state_estimation_at_scan` 对 ARiADNE 本身不是必需
- `/terrain_map_ext` 对 ARiADNE 本身也不是必需

但你可以先不删它们，因为它们不会妨碍最小验证。

### 4.4 保证 `/way_point` 只有一个发布者

这是最重要的运行约束之一。

你当前系统里：

- `far_planner`
- `tare_planner`
- 未来的 `rl_planner`

都可能发布 `/way_point`

所以最小改造方案必须保证：

- ARiADNE 模式下，不启动 `tare_planner`
- 也不启动会同时发布 `/way_point` 的其他高层规划器

---

## 5. ARiADNE 在你当前系统里的真实输入输出接口

### 5.1 ARiADNE 需要的接口

在 `humble` 分支里，`rl_planner` 明确订阅：

- `/projected_map`，类型 `nav_msgs/OccupancyGrid`
- `/state_estimation`，类型 `nav_msgs/Odometry`

并发布：

- `/way_point`，类型 `geometry_msgs/PointStamped`

### 5.2 你的系统已经有的接口

当前系统已经有：

- `/state_estimation`
- `/registered_scan`
- `/sensor_scan`
- `/terrain_map`
- `/way_point` 消费端 `localPlanner`

其中最关键的是：

- `localPlanner` 已经直接订阅 `/way_point`
- `sensor_scan_generation` 已经发布 `/sensor_scan`

这意味着中间只差一层：

- `/sensor_scan -> octomap_server -> /projected_map`

---

## 6. 接入时最关键的参数和改动点

这部分是整个最小方案里最关键的技术细节。

### 6.1 `base_frame` 必须改成 `sensor_at_scan`

这是第一优先级。

当前 `ARiADNE-ROS-Planner` 官方 `humble` launch 默认：

- `base_frame = sensor`

但你的 `/sensor_scan` 是由 `sensor_scan_generation` 发布的，其 `header.frame_id` 是：

- `sensor_at_scan`

因此，最小改造方案里必须做下面二选一：

#### 方案 A：直接改 ARiADNE launch 参数

把：

```text
base_frame = sensor
```

改成：

```text
base_frame = sensor_at_scan
```

这是我更推荐的做法。

#### 方案 B：额外补一条 `sensor_at_scan -> sensor` 的 TF

能做，但不如方案 A 直接。

### 6.2 `autonomyMode` 必须设成 `true`

当前 TARE 版本 launch 已经把 `local_planner.launch` 的：

```text
autonomyMode = true
```

打开了。

ARiADNE 版本也应该保持这一点，否则：

- `/way_point` 有可能发布了
- 但车辆不进入自主 waypoint 跟随模式

### 6.3 起步阶段尽量用官方默认参数

为了最小改造，不建议一开始就同时改一堆规划参数。

建议首轮先保持接近官方默认：

- `map_resolution = 0.4`
- `sensor_range = 20.0`
- `node_resolution = 2.0`
- `replanning_frequency = 2.5`

先验证链路。

只有当链路已经稳定、行为明显不适合你的场景时，再做第二轮调参。

### 6.4 `publish_graph` 首轮可以设成 `false`

在最小改造阶段，如果你更关心稳定性和性能而不是图可视化，建议：

- `publish_graph = false`

这样可以减少无关可视化开销。

### 6.5 `terrain_analysis_ext` 可以先保留，也可以后续裁掉

从最小方案看：

- ARiADNE 不需要 `terrain_map_ext`
- `localPlanner` 主要看 `terrain_map`

因此，`terrain_analysis_ext` 在 ARiADNE 模式下不是刚需。

但为了降低首轮改动量，你可以先保留。

---

## 7. 建议的最小 launch 结构

下面是逻辑结构，不是可直接复制运行的最终代码。

```python
start_fastlio
start_registered_scan_relay
start_odom_relay

start_sensor_scan_generation
start_terrain_analysis
start_terrain_analysis_ext   # 可先保留

start_local_planner          # autonomyMode=true

start_octomap_server         # cloud_in <- /sensor_scan
start_ariadne_rl_planner     # /projected_map + /state_estimation -> /way_point

start_visualization_tools
start_rviz
```

其中新增节点的核心配置应当类似：

```python
Node(
    package='octomap_server',
    executable='octomap_server_node',
    remappings=[('cloud_in', 'sensor_scan')],
    parameters=[
        {'frame_id': 'map'},
        {'base_frame_id': 'sensor_at_scan'},
        {'resolution': 0.4},
        {'occupancy_min_z': 0.0},
        {'occupancy_max_z': 1.2},
    ]
)

Node(
    package='rl_planner',
    executable='rl_planner',
    parameters=[
        {'publish_graph': False},
        {'node_resolution': 2.0},
        {'sensor_range': 20.0},
        {'map_resolution': 0.4},
        {'replanning_frequency': 2.5},
    ]
)
```

---

## 8. 为什么这个方案优先于“直接改训练仓库”

因为它能把问题拆开。

### 8.1 先验证部署，不先碰训练

如果你直接从 `large-scale-DRL-exploration` 开始训练，会同时混入：

- 训练稳定性问题
- 场景分布问题
- ROS 接入问题
- local planner 跟踪问题

这会让排错边界完全混乱。

### 8.2 先用自带 checkpoint 看方向

如果预训练模型接进来之后：

- 行为方向就明显比 TARE 更合理

那你就知道这条路值得继续。

如果预训练模型接进来之后：

- 话题、TF、投影地图全是问题

那训练新模型也无济于事。

---

## 9. 最小改造方案的分阶段验证方法

### 9.1 阶段 A：只验证 `octomap_server`

检查：

- `/sensor_scan` 是否正常
- `/projected_map` 是否持续输出
- 地图是否对齐 `map` 坐标系

### 9.2 阶段 B：只验证 `rl_planner`

检查：

- `/way_point` 是否持续发布
- 是否存在明显 waypoint 振荡
- 是否能随着地图更新做决策

### 9.3 阶段 C：联通 `localPlanner`

检查：

- `/way_point -> /path -> /cmd_vel` 是否贯通
- local planner 是否能稳定追踪高层输出

### 9.4 阶段 D：Unity 场景对比 TARE vs ARiADNE

你最应该记录：

- 是否完成探索
- 走过的总路径
- 是否在岔路口更果断
- 是否存在明显来回折返

### 9.5 阶段 E：实机低速验证

首轮实机建议：

- 低速
- 小场景
- 先观察 `/way_point` 与 `/cmd_vel`
- 不要一开始就跑复杂长距离任务

---

## 10. 这套最小方案的主要风险

### 10.1 风险 1：`/sensor_scan` 与 `base_frame` 不一致

这是最高优先级风险。

不解决这个问题，`/projected_map` 很可能不稳定甚至没有正确结果。

### 10.2 风险 2：投影地图质量不足

ARiADNE 吃的是 occupancy grid。

如果 Octomap 投影质量很差，就会直接影响高层策略质量。

### 10.3 风险 3：高层 waypoint 太跳，低层跟不上

ARiADNE 的 waypoint 选择逻辑和 TARE 可能明显不同。

这可能导致：

- 高层规划合理
- 但 low-level 跟踪体验差

### 10.4 风险 4：预训练分布与场景不匹配

如果你的场景比论文和作者 demo 更窄、更拥挤或更特殊，预训练模型未必直接好用。

这时要先区分：

- 是策略分布问题
- 还是链路 / TF / 地图质量问题

---

## 11. 我建议你实际执行时的最小任务清单

### 第一轮

1. 独立拉起 `ARiADNE-ROS-Planner` `humble`
2. 用官方 checkpoint 跑官方 Gazebo
3. 记录 `/way_point`、`/runtime`、完成探索情况

### 第二轮

1. 在 `autonomy_stack` 新建 `system_scout_hesai_with_ariadne.launch.py`
2. 删掉 TARE 节点
3. 新增 `octomap_server_node`
4. 新增 `rl_planner`
5. 把 `base_frame` 设成 `sensor_at_scan`
6. 保持 `autonomyMode=true`

### 第三轮

1. 先 Unity 验证
2. 再 bag 回放验证
3. 最后实机低速验证

### 第四轮

如果预训练方向正确但效果一般，再决定是否做训练微调。

---

## 12. 总结

把 ARiADNE 接进你当前 `autonomy_stack` 的最小改造方案，本质上不是“重建导航栈”，而是：

- 让现有系统继续负责：
  - 位姿
  - 点云
  - 局部地形
  - 碰撞规避
  - waypoint 跟踪
- 只让 ARiADNE 接管：
  - 从当前地图与位姿生成探索目标点

因此，这个改造的核心不是语言，不是训练，而是三个工程点：

1. `/sensor_scan -> /projected_map` 是否稳定
2. `base_frame` / TF 是否一致
3. `/way_point` 是否只由一个高层模块发布

如果这三点处理好，ARiADNE 接入你当前系统是现实可行的。

