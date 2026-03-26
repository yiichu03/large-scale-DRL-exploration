# ARiADNE 实验记录模板

本模板用于记录：

- 官方 Gazebo 验证
- 接入当前 `autonomy_stack` 的 Unity / bag / 实机实验
- TARE vs ARiADNE 对比结果

建议每次实验复制一份并填写。

---

## 1. 基本信息

- 实验日期：
- 实验人：
- 平台：
  - `Gazebo / Unity / bag / 实机`
- 模式：
  - `TARE / ARiADNE`
- 代码分支：
- Launch 文件：
- 主要参数版本：

---

## 2. 环境描述

- 场景名称：
- 场景类型：
  - `走廊 / 房间 / 室内混合 / 室外`
- 地图规模：
- 障碍物特征：
- 是否有动态障碍：

---

## 3. 输入链路检查

### 话题状态

| 话题 | 是否正常 | 备注 |
|---|---|---|
| `/state_estimation` |  |  |
| `/registered_scan` |  |  |
| `/sensor_scan` |  |  |
| `/projected_map` |  |  |
| `/terrain_map` |  |  |
| `/way_point` |  |  |
| `/path` |  |  |
| `/cmd_vel` |  |  |

### TF / frame 检查

- `map` 是否稳定：
- `sensor_at_scan` 是否正常：
- `vehicle` 是否正常：
- 是否存在 frame 错位：

---

## 4. 运行结果

### 行为观察

- 是否能持续产生 waypoint：
- 是否存在 waypoint 来回振荡：
- 是否能进入未知区域而不是原地徘徊：
- 是否能完成探索：

### 轨迹特征

- 是否绕远：
- 是否在岔路口犹豫：
- 是否有明显重复覆盖：

---

## 5. 定量指标

如果能采集，尽量记录下列指标。

| 指标 | TARE | ARiADNE | 备注 |
|---|---|---|---|
| 是否完成探索 |  |  |  |
| 总运行时间 |  |  |  |
| 总路径长度 |  |  |  |
| 平均规划频率 |  |  |  |
| 平均 `/runtime` |  |  |  |
| 明显卡顿次数 |  |  |  |
| 人工接管次数 |  |  |  |

---

## 6. 失败模式记录

如果失败，请尽量按下面分类记录。

| 失败类型 | 是否出现 | 描述 |
|---|---|---|
| 无 `/projected_map` |  |  |
| 无 `/way_point` |  |  |
| 有 `/way_point` 但不动 |  |  |
| waypoint 振荡 |  |  |
| 局部避障失败 |  |  |
| 地图错位 |  |  |
| TF 错误 |  |  |
| 其他 |  |  |

---

## 7. 主观评价

- 与 TARE 相比，ARiADNE 最大优点：
- 与 TARE 相比，ARiADNE 最大问题：
- 当前更像是链路问题还是策略问题：
- 是否值得继续投入：

---

## 8. 下一步动作

- [ ] 保持现状，进入下一场景验证
- [ ] 调整 `base_frame`
- [ ] 调整 `node_resolution`
- [ ] 调整 `waypoint_threshold`
- [ ] 调整 `next_waypoint_threshold`
- [ ] 调整 `terrain_analysis` 参数
- [ ] 准备微调训练
- [ ] 暂停 ARiADNE 路线

