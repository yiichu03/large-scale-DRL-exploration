# 另一个 AI 在剩余额度内可做的紧急任务

**背景**：我们计划用 ARiADNE (large-scale-DRL-exploration) 的 DRL 探索策略替换当前 autonomy_stack 中的 TARE planner。另一个 AI 还剩约 40 分钟额度（到 15:40 清零），以下任务按优先级排列，可以让它立刻开始做。

**当前设备**：如果另一个 AI 在 AGX Orin 上，下面标注了哪些任务适合在 Orin 上做，哪些适合在笔记本上做。

---

## 任务 1（最高优先级）：阅读 ARiADNE ROS Planner 仓库

**预计耗时**：5-10 分钟
**适合设备**：任意有网络的设备

DRL 训练仓库已在本地：`~/projects/thermal_nav/large-scale-DRL-exploration`

ARiADNE ROS Planner 是另一个仓库（ROS 部署接口），需要先克隆：
```bash
cd ~/projects/thermal_nav
git clone https://github.com/marmotlab/ARiADNE-ROS-Planner.git
cd ARiADNE-ROS-Planner
git checkout humble   # ROS2 Humble 分支
```

> 注意：`large-scale-DRL-exploration`（训练代码）已经在本地了，不需要重新克隆。
> `ARiADNE-ROS-Planner`（ROS 部署接口）是另一个仓库，这个需要克隆。

完成后请 AI 做以下分析并写入文档：
1. 阅读 README.md，总结 ROS2 Humble 分支的使用方法
2. 列出所有 ROS 话题名（输入/输出），与 autonomy_stack 对比
3. 找到预训练权重文件的位置和格式
4. 阅读 launch 文件，列出所有可配置参数
5. 阅读 parameter.py，对比 large-scale-DRL-exploration 的 parameter.py，标出差异

---

## 任务 2（高优先级）：分析 autonomy_stack 的 TARE 接口

**预计耗时**：10-15 分钟
**适合设备**：任意（只需读代码）

让 AI 做一个接口分析文档，回答：

1. TARE planner 订阅了哪些话题？发布了哪些话题？
   - 重点关注：输入的地图格式、输出的 waypoint 格式
   ```bash
   # 关键文件
   grep -r "subscribe\|Subscribe\|publish\|Publisher" \
     src/exploration_planner/tare_planner/src/ \
     --include="*.cpp" --include="*.h"
   ```

2. TARE 是如何被 launch 文件启动的？
   ```bash
   cat src/base_autonomy/vehicle_simulator/launch/system_unity_with_exploration_planner.launch
   # 或对应的 system_simulation_with_exploration_planner.launch
   ```

3. local_planner 订阅 waypoint 的话题名和消息类型是什么？
   ```bash
   grep -r "way_point\|waypoint\|goal" \
     src/base_autonomy/local_planner/src/ \
     --include="*.cpp" --include="*.h"
   ```

4. 最终输出一个**接口对齐表**：
   ```
   | 功能     | TARE 话题名 | TARE 消息类型 | ARiADNE 需要 | 是否匹配 |
   |---------|------------|--------------|-------------|---------|
   | 地图输入  | ???        | ???          | ???         | ???     |
   | 位姿输入  | ???        | ???          | ???         | ???     |
   | 目标输出  | ???        | ???          | ???         | ???     |
   ```

---

## 任务 3（高优先级）：配置 Python 环境

**预计耗时**：5-10 分钟
**适合设备**：准备跑训练/测试的机器

```bash
# 创建独立 conda 环境（避免污染现有 ROS 环境）
conda create -n ariadne python=3.10 -y
conda activate ariadne
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu118
pip install scikit-image matplotlib ray tensorboard

# 验证
python -c "import torch; print(torch.__version__, torch.cuda.is_available())"
```

如果在 AGX Orin（ARM64）上：
```bash
# Orin 用 JetPack 自带的 PyTorch，不要用 pip 的 x86 版
# 检查是否已有 PyTorch
python3 -c "import torch; print(torch.__version__, torch.cuda.is_available())"
```

---

## 任务 4（中优先级）：在 2D 环境中快速测试 DRL

**预计耗时**：10 分钟
**适合设备**：有 GPU 的机器（笔记本 RTX 4060 或 Orin）

```bash
cd ~/projects/thermal_nav/large-scale-DRL-exploration
conda activate ariadne

# 先测试单个 episode（不训练，只看代码能否跑通）
python -c "
from worker import Worker
from model import PolicyNet
from parameter import *
import torch, numpy as np
torch.manual_seed(42)
np.random.seed(42)
model = PolicyNet(NODE_INPUT_DIM, EMBEDDING_DIM)
worker = Worker(0, model, 1, save_image=True)
worker.run_episode()
print('Travel dist:', worker.perf_metrics['travel_dist'])
print('Explored rate:', worker.perf_metrics['explored_rate'])
print('Success:', worker.perf_metrics['success_rate'])
"
```

如果成功，会在 `gifs/` 文件夹生成可视化图片。这验证了：
- 代码环境是否正确
- 2D 仿真是否能运行
- 随机策略的探索行为（基线）

---

## 任务 5（中优先级）：调研 CMU Development Environment Gazebo 仿真

**预计耗时**：10 分钟
**适合设备**：任意

让 AI 访问 https://www.cmu-exploration.com/development-environment 并分析：

1. CMU Development Environment 的 ROS2 Humble 版本是否可用？
2. Gazebo 仿真的 indoor 场景和我们 Unity 的 office_building_2 场景有多大差异？
3. 在笔记本上配置 Gazebo 仿真需要多少额外空间和依赖？
4. 是否可以直接把 ARiADNE ROS Planner 跑在 CMU 的 Gazebo 环境里？

---

## 任务 6（低优先级，如果还有时间）：阅读论文关键部分

**预计耗时**：15 分钟

让 AI 阅读论文 arXiv:2403.10833 的以下部分，用中文写一个简明摘要：

1. Fig.1 系统架构图 → 翻译并解释
2. Section III Method → 总结 informative graph 的构建方法
3. Section IV Experiments → 总结训练参数和对比实验结果
4. 特别关注：与 TARE 的对比数据（如果有的话）

---

## 给另一个 AI 的提示词模板

复制以下内容发给另一个 AI：

```
我正在做一个项目：用 ARiADNE（DRL探索算法）替换 autonomy_stack_mecanum_wheel_platform 里的 TARE planner。

请帮我做以下任务（按优先级顺序）：

1. 克隆 ARiADNE ROS Planner 仓库（注意这是 ROS 部署接口，不是训练代码）的 humble 分支到
   ~/projects/thermal_nav/，阅读 README 和代码，总结 ROS2 话题接口、预训练权重位置、launch 参数
   （DRL 训练代码仓库 large-scale-DRL-exploration 已在本地，不需要克隆）

2. 分析 autonomy_stack 中 TARE planner 的 ROS 接口（订阅/发布的话题名和消息类型），
   与 ARiADNE 做接口对齐表

3. 配置 conda 环境 ariadne，安装 PyTorch 和依赖

4. 在 large-scale-DRL-exploration 中用随机策略跑一个 episode 测试代码环境

请把分析结果写入文档保存到 `large-scale-DRL-exploration/docs_liuyi/claude/` 文件夹。

相关路径：
- autonomy_stack: ~/projects/thermal_nav/autonomy_stack_mecanum_wheel_platform
- DRL 训练代码（已在本地）: ~/projects/thermal_nav/large-scale-DRL-exploration
- 项目背景文档: ~/projects/thermal_nav/project_context.md
- 可行性分析: ~/projects/thermal_nav/large-scale-DRL-exploration/docs_liuyi/claude/feasibility_analysis.md
```

---

*文档位置：`large-scale-DRL-exploration/docs_liuyi/claude/urgent_tasks_for_other_ai.md`*
*创建时间：2026-03-26*


