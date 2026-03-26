# Codex Memory

## 1. 当前目标

你正在评估是否将 `ARiADNE / large-scale-DRL-exploration` 引入现有项目：

- 当前系统：`/home/liuyi/projects/thermal_nav/autonomy_stack_mecanum_wheel_platform`
- 训练仓库：`/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration`
- 论文：`/home/liuyi/Documents/papers/thermal-nav-docs/liuyi/Deep_Reinforcement_Learning-Based_Large-Scale_Robot_Exploration.pdf`

核心目标不是重写整套导航，而是：

> 用 ARiADNE 替换现有 TARE exploration 模块，保留现有 SLAM、scan relay、terrain analysis、local planner、path follower。

---

## 2. 已确认的重要事实

### 2.1 `ARiADNE-ROS-Planner` 真实情况

- 存在独立 `humble` 分支
- `humble` 分支是 ROS2 版本
- 自带 `checkpoint.pth`
- 可先不训练，直接验证预训练模型

### 2.2 `ARiADNE-ROS-Planner` `humble` 版高层接口

- 订阅：
  - `/projected_map` (`nav_msgs/OccupancyGrid`)
  - `/state_estimation` (`nav_msgs/Odometry`)
- 发布：
  - `/way_point` (`geometry_msgs/PointStamped`)

并且：

- launch 内会起 `octomap_server_node`
- `octomap_server_node` 吃 `sensor_scan`
- `octomap_server_node` 生成 `/projected_map`

### 2.3 当前 `autonomy_stack` 已有的关键接口

已存在：

- `/state_estimation`
- `/registered_scan`
- `/sensor_scan`
- `/terrain_map`
- `/way_point` 消费端 `localPlanner`

`localPlanner` 当前直接订阅：

- `/state_estimation`
- `/registered_scan`
- `/terrain_map`
- `/way_point`

### 2.4 当前最关键的接入结论

最小替换点不是整个规划栈，而是：

```text
TARE -> /way_point
```

替换成：

```text
octomap_server -> /projected_map -> rl_planner -> /way_point
```

---

## 3. 当前最需要记住的工程风险

### 3.1 `base_frame` / TF 风险

`ARiADNE-ROS-Planner` 官方 launch 默认：

- `base_frame = sensor`

但当前 `sensor_scan_generation` 发布的 `/sensor_scan` 使用：

- `frame_id = sensor_at_scan`

所以接入时必须重点处理：

- 把 `base_frame` 改成 `sensor_at_scan`
- 或额外补一层 TF

优先推荐直接改 `base_frame`。

### 3.2 `/way_point` 多发布者冲突

以下高层模块都可能发布 `/way_point`：

- `far_planner`
- `tare_planner`
- `rl_planner`

ARiADNE 模式下必须保证：

- `/way_point` 只有一个发布者

### 3.3 先别把训练和接入混在一起

建议顺序：

1. 官方 Gazebo 跑通 `ARiADNE-ROS-Planner`
2. 接到你自己的 Unity / bag / 实机链路
3. 只有当预训练方向对但效果一般时，再考虑 `large-scale-DRL-exploration` 训练微调

---

## 4. 当前文档位置

当前统一文档目录是：

- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/docs_liuyi/`
- 具体工作文档集中放在：
  - `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/docs_liuyi/codex/`

说明：

- `docs_ly/` 已经清理掉，不再使用
- `autonomy_stack_mecanum_wheel_platform` 下面那份重复文档目录也已经删除
- `claude/` 和 `codex/` 现在是并级目录
- 后续协作时，默认优先看 `docs_liuyi/README.md` 和 `docs_liuyi/codex/`

## 5. 已完成的文档资产

当前 `docs_liuyi/codex/` 下的重点文档有：

- `project_code_walkthrough.md`
- `paper_reading_deep_rl_large_scale_robot_exploration.md`
- `ariadne_three_stage_practical_guide.md`
- `ariadne_autonomy_stack_minimal_integration_plan.md`
- `ariadne_topic_tf_parameter_matrix.md`
- `ariadne_integration_debug_handbook.md`
- `ariadne_experiment_record_template.md`
- `system_scout_hesai_with_ariadne.launch.py`

这份 `memory.md` 的作用是：

- 帮后续协作快速恢复上下文
- 避免重复核对同一批接口事实
- 让下一次工作直接从“接入和验证”继续，而不是重新做背景调查

---

## 6. 当前建议的下一步

最优先的实际动作：

1. 在独立工作区先拉起 `ARiADNE-ROS-Planner` `humble`
2. 让官方 checkpoint 在官方 Gazebo 环境里产出稳定 `/way_point`
3. 再基于本目录中的 `system_scout_hesai_with_ariadne.launch.py` 草案，接入当前 `autonomy_stack`

如果继续推进，本目录最该先用的文件是：

- `system_scout_hesai_with_ariadne.launch.py`
- `ariadne_topic_tf_parameter_matrix.md`
- `ariadne_integration_debug_handbook.md`

---

## 7. 协作约定

为了减少后续混乱，默认遵循下面几个约定：

- 文档主目录：`docs_liuyi/codex/`
- 总索引：`docs_liuyi/README.md`
- 需要记录新事实或新决策时，优先更新 `memory.md`
- 如果产生新的接入方案、实验记录或排错结论，优先放进 `docs_liuyi/codex/`
