# ARiADNE 接入话题 / TF / 参数对照表

本文件用于把：

- `ARiADNE-ROS-Planner`
- 当前 `autonomy_stack_mecanum_wheel_platform`
- 最小接入方案

三者对应关系一次性讲清楚。

---

## 1. 高层输入输出对照

| 项目 | `ARiADNE-ROS-Planner` 需要/输出 | 当前 `autonomy_stack` 已有/消费 | 最小接入方案 |
|---|---|---|---|
| 机器人位姿 | `/state_estimation` | 已有 `/state_estimation` | 直接复用 |
| 传感器点云 | `sensor_scan` 给 `octomap_server` | 已有 `/sensor_scan` | 直接复用 |
| 占据栅格图 | `/projected_map` | 当前没有现成高层 OccupancyGrid 入口 | 新增 `octomap_server_node` 生成 |
| 高层目标点 | `/way_point` | `localPlanner` 已消费 `/way_point` | 直接复用 |

---

## 2. 当前系统链路中保留哪些模块

| 模块 | 是否保留 | 原因 |
|---|---|---|
| `fast_lio` | 保留 | 继续提供位姿与配准点云 |
| `registered_scan_frame_relay` | 保留 | 继续统一点云坐标系 |
| `odom_frame_relay` | 保留 | 继续统一位姿坐标系 |
| `sensor_scan_generation` | 保留 | 继续产出 `/sensor_scan` |
| `terrain_analysis` | 保留 | `localPlanner` 仍需 `/terrain_map` |
| `terrain_analysis_ext` | 可保留 | ARiADNE 不需要，但首轮可不删 |
| `localPlanner` | 保留 | 继续做局部路径与碰撞规避 |
| `pathFollower` | 保留 | 继续输出 `/cmd_vel` |
| `tare_planner_node` | 删除/停用 | 被 ARiADNE 替换 |

---

## 3. `/way_point` 关系

### 当前 TARE 模式

```text
TARE -> /way_point -> localPlanner
```

### ARiADNE 模式

```text
rl_planner -> /way_point -> localPlanner
```

### 关键约束

同一时刻只能有一个模块稳定发布 `/way_point`。

因此：

- `ARiADNE` 模式下不要同时起 `tare_planner`
- 也不要同时起会发布 `/way_point` 的其他高层规划器

---

## 4. TF / frame 对照

### 当前系统里已知的重要 frame

| 名称 | 作用 |
|---|---|
| `map` | 全局地图系 |
| `camera_init` | FAST-LIO 原始世界系桥接对象 |
| `body` | FAST-LIO / 机体坐标系 |
| `sensor` | 当前栈中一个静态参考 frame |
| `sensor_at_scan` | `sensor_scan_generation` 生成点云时使用的 frame |
| `vehicle` | `localPlanner` / 路径显示相关 frame |

### 当前最需要注意的点

`/sensor_scan` 的 `frame_id` 不是 `sensor`，而是：

- `sensor_at_scan`

### 与 ARiADNE 官方默认的冲突

`ARiADNE-ROS-Planner` 官方 launch 默认：

- `base_frame = sensor`

但你当前 `/sensor_scan` 是：

- `frame_id = sensor_at_scan`

### 建议处理方式

最小改造时优先这样做：

```text
ARiADNE launch:
  base_frame := sensor_at_scan
```

而不是再人为补额外 frame 转换。

---

## 5. 当前链路和目标链路

### 当前 TARE 链路

```text
/terrain_map + /terrain_map_ext + /state_estimation_at_scan + /registered_scan
  -> tare_planner_node
  -> /way_point
```

### 目标 ARiADNE 链路

```text
/sensor_scan
  -> octomap_server_node
  -> /projected_map

/projected_map + /state_estimation
  -> rl_planner
  -> /way_point
```

---

## 6. 关键参数对照

### 当前 `ARiADNE-ROS-Planner` 官方默认

| 参数 | 默认值 | 说明 |
|---|---|---|
| `map_resolution` | `0.4` | 栅格分辨率 |
| `sensor_range` | `20.0` | 传感器最大范围 |
| `node_resolution` | `2.0` | 图节点间距 |
| `utility_range_factor` | `0.5` | utility 半径因子 |
| `waypoint_threshold` | `2.0` | waypoint 到达阈值 |
| `next_waypoint_threshold` | `4.0` | 下一个 waypoint 规划距离阈值 |
| `replanning_frequency` | `2.5` | 重规划频率 |

### 接入当前系统时的首轮建议

首轮尽量先保持接近官方默认：

| 参数 | 首轮建议 |
|---|---|
| `map_resolution` | `0.4` |
| `sensor_range` | `20.0` |
| `node_resolution` | `2.0` |
| `publish_graph` | `false` |
| `replanning_frequency` | `2.5` |
| `base_frame` | `sensor_at_scan` |

理由是：

- 先验证链路
- 再做参数优化

---

## 7. 最小接入方案的一句话总结

如果只记一件事，就记这个：

> 保留你当前的 `sensor_scan_generation + terrain_analysis + localPlanner`，新增 `octomap_server + rl_planner`，删除 `tare_planner`，并把 `ARiADNE` 的 `base_frame` 改成 `sensor_at_scan`。

