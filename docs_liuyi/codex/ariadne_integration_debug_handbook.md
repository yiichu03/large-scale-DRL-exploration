# ARiADNE 接入排错手册

本手册面向三个阶段的排错：

1. 官方 Gazebo + `ARiADNE-ROS-Planner`
2. 接入当前 `autonomy_stack`
3. Unity / bag / 实机联调

---

## 1. 排错原则

不要一上来只看“机器人为什么不动”。

应该按这条链逐段排：

```text
/sensor_scan
  -> /projected_map
  -> /way_point
  -> /path
  -> /cmd_vel
```

每段单独确认后再看下一段。

---

## 2. 问题：没有 `/projected_map`

### 可能原因

1. `octomap_server_node` 没起
2. `cloud_in` 没有正确 remap 到 `/sensor_scan`
3. `/sensor_scan` 根本没有数据
4. `base_frame_id` / TF 不对

### 检查顺序

1. `ros2 node list | grep octomap`
2. `ros2 topic echo /sensor_scan --once`
3. `ros2 topic list | grep projected_map`
4. 看 `octomap_server` 终端日志
5. 检查 `base_frame_id`

### 当前系统中特别要查的点

你的 `/sensor_scan` 使用的 frame 是：

- `sensor_at_scan`

如果 `octomap_server` 还在用：

- `base_frame_id=sensor`

很容易卡住。

---

## 3. 问题：有 `/projected_map`，但没有 `/way_point`

### 可能原因

1. `rl_planner` 没起
2. `rl_planner` 没吃到 `/state_estimation`
3. `checkpoint.pth` 没找到
4. `/projected_map` 内容异常
5. `rl_planner` 认为没有可用 utility 节点

### 检查顺序

1. `ros2 node list | grep rl_planner`
2. `ros2 topic echo /state_estimation --once`
3. `ros2 topic echo /projected_map --once`
4. 看 `rl_planner` 日志
5. 检查模型路径是否存在

### 重点判断

如果 `rl_planner` 起了，但一条 `/way_point` 都没有，优先怀疑：

- 地图没有被正确理解
- 起始节点没初始化成功
- 模型文件没正确加载

---

## 4. 问题：有 `/way_point`，但车不动

### 可能原因

1. `localPlanner` 没有进入 autonomy/waypoint 模式
2. `/way_point` 频率太低或跳点太大
3. `localPlanner` 没能生成有效 `/path`
4. `pathFollower` 没输出 `/cmd_vel`

### 检查顺序

1. `ros2 topic echo /way_point`
2. `ros2 topic echo /path`
3. `ros2 topic echo /cmd_vel`
4. 检查 `local_planner.launch` 中 `autonomyMode`

### 当前系统里的关键点

TARE 版本 launch 已经把：

```text
autonomyMode = true
```

ARiADNE 版本也必须保持这一点。

---

## 5. 问题：有 `/way_point`，但局部运动很差

### 现象

- waypoint 合理，但机器人跟踪不顺
- 容易刹停、来回调整、贴障碍

### 常见原因

1. 高层 waypoint 间距与 `localPlanner` 偏好不一致
2. `waypoint_threshold` 太小或太大
3. `next_waypoint_threshold` 太激进
4. `terrain_map` 对障碍表达偏保守

### 处理建议

首轮不要先改模型。

先改：

- `waypoint_threshold`
- `next_waypoint_threshold`
- `maxSpeed`

再看效果。

---

## 6. 问题：地图看起来歪了 / 探索方向不对

### 优先怀疑

1. `/state_estimation` 的 yaw 方向仍有问题
2. `/sensor_scan` frame 与 `map` 对齐关系不对
3. `octomap_server` 的 `base_frame_id` 错了

### 检查方法

1. RViz 看 `/sensor_scan` 是否落在机器人周围正确位置
2. RViz 看 `/projected_map` 是否和点云大体一致
3. 看 `/way_point` 是否落在明显错误方向

---

## 7. Unity / bag / 实机三种场景的排错顺序

### Unity 仿真

先查：

1. `/sensor_scan`
2. `/projected_map`
3. `/way_point`
4. `/path`

### bag 回放

重点查：

1. 时间同步
2. `use_sim_time`
3. `/state_estimation` 与 `/sensor_scan` 的时序

### 实机

重点查：

1. 实时 TF 是否稳定
2. 点云质量是否比仿真差很多
3. `/cmd_vel` 是否确实到达底盘

---

## 8. 一套最实用的快速排错命令

```bash
ros2 node list
ros2 topic list
ros2 topic echo /sensor_scan --once
ros2 topic echo /projected_map --once
ros2 topic echo /state_estimation --once
ros2 topic echo /way_point --once
ros2 topic echo /path --once
ros2 topic echo /cmd_vel --once
```

如果可以开 RViz，再同时看：

- `/sensor_scan`
- `/projected_map`
- `/terrain_map`
- `/way_point`
- `/path`

---

## 9. 最后记住一条

如果问题还没定位清楚，不要太早怀疑“模型不好”。

接入阶段的大多数问题通常是：

- 话题没接对
- TF 不一致
- `base_frame` 错了
- `/way_point` 冲突
- 局部控制参数不匹配

先把链路问题排干净，再判断是否需要训练微调。

