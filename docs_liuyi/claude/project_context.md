# 项目背景上下文（DRL 探索方向）

> 此文档供 AI 助手在任意设备上快速了解项目全貌。
> 上次更新：2026-03-26

---

## 整体研究方向

研究自主导航机器人在室内环境（走廊、办公楼）中的**自主探索**能力。
核心问题：如何让机器人在未知室内环境中高效、完整地完成地图探索。

---

## 硬件平台

- **机器人**：T-Bot Mecanum 轮平台（CMU Ji Zhang 组开源）
- **雷达**：Livox Mid-360（1.2m 盲区）
- **主控**：Intel NUC i7
- **扩展计算**：Jetson AGX Orin（ARM64）
- **车轮**：麦克纳姆轮（室内地毯最佳），可换标准轮

## 开发设备

| 设备 | 用途 | 关键规格 |
|------|------|---------|
| x86 笔记本 | 仿真开发、训练 | Ubuntu 22.04, RTX 4060 8GB, RAM 15GB |
| AGX Orin | 实机部署 | ARM64, JetPack, ROS2 Humble |

---

## 涉及的三个仓库

### 1. autonomy_stack_mecanum_wheel_platform（已在本地，已配置好仿真）

**路径**：`~/projects/thermal_nav/autonomy_stack_mecanum_wheel_platform`
**来源**：CMU Ji Zhang 组（`github.com/jizhang-cmu/autonomy_stack_mecanum_wheel_platform`）
**当前分支**：`x86_simulation`（基于 `humble` 分支）
**状态**：仿真环境已配好，可运行 Unity 仿真 + TARE 探索 + FAR 路径规划

系统架构：
```
传感器层：Livox Mid-360 → SLAM (arise_slam_mid360)
                              ↓
规划层：terrain_analysis → local_planner（避障 + waypoint 跟随）
              ↑
      [三选一规划器]
      tare_planner（TARE 探索规划）  ← 要被替换
      far_planner（FAR 路径规划）
      无规划器（手动/waypoint 模式）
```

仿真：Unity 渲染，通过 ROS-TCP-Endpoint 桥接，当前场景 `office_building_2`

### 2. large-scale-DRL-exploration（已在本地）

**路径**：`~/projects/thermal_nav/large-scale-DRL-exploration`
**来源**：MARMot Lab (NUS)（`github.com/marmotlab/large-scale-DRL-exploration`）
**当前分支**：`new_version`（ground truth critic 变体）
**状态**：代码已克隆，环境未配置，未开始训练

纯 Python 的 DRL 训练框架（PyTorch + Ray），在 2D 栅格地图上训练探索策略。
自带 300+ 张建筑平面图（`maps/`）作为训练场景。
训练需要 8GB VRAM + 20GB RAM。

### 3. ARiADNE-ROS-Planner（待克隆）

**路径**：`~/projects/thermal_nav/ARiADNE-ROS-Planner`（计划路径）
**来源**：MARMot Lab (NUS)（`github.com/marmotlab/ARiADNE-ROS-Planner`）
**需要的分支**：`humble`（ROS2 Humble 支持）
**状态**：尚未克隆

这是训练好的 DRL 策略部署到 ROS 的接口层。**自带预训练权重**，推理只用 CPU。
基于 CMU Autonomous Exploration Development Environment（与 autonomy_stack 同源）。

---

## 三个仓库的关系

```
large-scale-DRL-exploration        ARiADNE-ROS-Planner        autonomy_stack
（DRL 训练，纯 Python）       →    （ROS2 部署接口）       →   （替换 tare_planner）
  2D 地图仿真训练                   自带预训练权重               Unity/实机运行
  输出 checkpoint.pth               读取 checkpoint              接收 waypoint
                                    发布 /way_point              local_planner 导航
```

两个项目共享 CMU 基础架构，仿真引擎不同（ARiADNE 用 Gazebo，autonomy_stack 用 Unity），
但下层导航模块（local_planner、terrain_analysis）同源，waypoint 接口一致。

---

## 当前问题：TARE 在走廊场景表现差

实测发现的关键缺陷（实机 + Unity 仿真均验证）：

1. **配置与环境强耦合**：只有 `indoor_small` 配置适用于走廊，`outdoor`/`indoor_large` 导致立即 rush home
2. **岔路口卡死**：local_planner 障碍检测过敏（`obstacleHeightThre=0.05m`），路口 freeze，TARE waypoint 不可达
3. **偶发 NaN bug**：复杂几何边界触发 NaN 坐标，机器人永久卡死
4. **缺乏高层理解**：TARE 是规则方法（TSP + viewpoint），无法学习走廊结构

→ 老师希望用 DRL（ARiADNE）替换 TARE，利用学习到的策略提升走廊探索能力。

---

## 替换方案：用 ARiADNE 替换 TARE

替换只发生在**探索决策层**，不动底层导航：

```
替换前：TARE → /way_point → local_planner
替换后：ARiADNE(DRL) → /way_point → local_planner（不改）
```

### 可行性结论（2026-03-26 分析）

| 问题 | 结论 |
|------|------|
| Python + C++ 能结合吗？ | 可以，ROS2 话题通信，语言透明 |
| 不结合能直接复现吗？ | 可以，large-scale-DRL-exploration 完全独立 |
| 需要数据集吗？ | 不需要，RL 自动生成训练数据 |
| 无头服务器能训练吗？ | 可以，matplotlib 用 agg 后端 |
| 有预训练权重吗？ | ARiADNE ROS Planner 自带 |
| 推理需要 GPU 吗？ | 不需要，CPU 即可 |

### 执行路线

1. 配置 Python 环境 → 跑通 2D 训练代码
2. 克隆 ARiADNE ROS Planner → 用预训练权重在 Gazebo indoor 场景验证效果
3. 接口对齐 → 把 ARiADNE 接入 autonomy_stack 替换 tare_planner
4. Unity 仿真对比 DRL vs TARE
5. 实机测试

### 需要注意的参数问题

| 参数 | DRL 默认值 | 走廊场景可能的问题 |
|------|-----------|------------------|
| `NODE_RESOLUTION` | 4.0m | 2m 宽走廊里节点太稀疏，建议调到 2.0m |
| `SENSOR_RANGE` | 16m | 可能接近覆盖整个走廊 |
| `NODE_PADDING_SIZE` | 360 | 节点数上限，调小 NODE_RESOLUTION 后需关注 |

---

## 相关文档索引

| 文件 | 位置 | 内容 |
|------|------|------|
| 项目总背景 | `~/projects/thermal_nav/project_context.md` | 原始项目上下文（autonomy_stack 为主） |
| 可行性分析 | `large-scale-DRL-exploration/docs_liuyi/claude/feasibility_analysis.md` | DRL 替换 TARE 的详细可行性分析 |
| Claude 项目上下文 | `large-scale-DRL-exploration/docs_liuyi/claude/project_context.md` | Claude 侧的项目背景、接口和参数摘要 |
| 紧急任务清单 | `large-scale-DRL-exploration/docs_liuyi/claude/urgent_tasks_for_other_ai.md` | 分配给另一个 AI 的任务 |
| TARE 调参记录 | `~/projects/thermal_nav/3_14.md` | 实机+仿真 TARE 问题深度分析 |
| 仿真运行手册 | `~/projects/thermal_nav/3_16.md` | 仿真运行流程、参数速查、场景管理 |
| x86 仿真配置 | `~/projects/thermal_nav/autonomy_stack_mecanum_wheel_platform/docs_ly/setup_x86_simulation.md` | 笔记本仿真环境配置过程 |

---

## 用户信息

- 刘奕，对 DRL 不太熟悉，正在学习中
- 习惯用中文交流
- 同时使用多个 AI 助手（笔记本 + AGX Orin 上各有一个）
- 已有 ROS2 和 autonomy_stack 实机+仿真经验
- 偏好先分析后动手，希望知其然知其所以然
