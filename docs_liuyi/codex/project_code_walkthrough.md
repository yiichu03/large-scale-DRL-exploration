# large-scale-DRL-exploration 代码与逻辑梳理

**日期**：2026-03-26  
**目的**：从“项目在做什么、一次 episode 怎么执行、各个文件分别负责什么、训练时到底在优化什么”这几个层面，较细致地理解当前仓库的代码与算法逻辑。

---

## 1. 项目一句话总结

这是一个用于**大尺度机器人自主探索**的深度强化学习训练框架。

它的核心思路不是让策略直接在像素地图上选动作，而是：

1. 先把当前已知地图抽象成一个**可达图（informative graph）**
2. 图上的每个节点表示一个候选观测位置
3. 节点的价值由它“能看到多少 frontier”来衡量
4. 策略网络只需要在当前节点的邻居中选择“下一步去哪个节点”
5. 用 SAC 训练策略网络和价值网络

这个仓库实现的是 README 中提到的 **ARiADNE ground truth critic variant**：  
**actor 使用 belief graph 做决策，critic 使用 ground-truth graph 评估动作。**

---

## 2. 这个项目到底在解决什么问题

从任务定义上看，项目解决的是：

> 给定一张初始完全未知的环境地图，机器人通过激光雷达逐步观测环境，持续选择下一个探索目标点，尽可能高效地覆盖更多未知区域。

它关注的不是低层运动控制，而是**高层探索决策**。

换句话说：

- 低层问题不是重点：机器人怎么平滑避障、怎么做动力学控制，不在这里细化
- 高层问题才是重点：当前应该往哪个方向继续探索，才能更快发现未知区域

因此，训练环境里机器人执行动作时有一个很重要的简化：

- 机器人不是沿连续轨迹慢慢走，而是**直接从当前图节点跳到下一个图节点**
- 奖励里用“移动距离惩罚”去近似运动代价

所以这个仓库更准确地说，是一个**探索策略学习器**，而不是完整导航栈。

---

## 3. 项目的整体架构

整个仓库可以拆成 5 层：

| 层次 | 核心文件 | 作用 |
|---|---|---|
| 训练调度层 | `driver.py`, `runner.py`, `parameter.py` | 启动 Ray worker、维护全局网络、采样 replay buffer、执行 SAC 更新 |
| episode 执行层 | `worker.py` | 跑完整 episode，收集 `(s, a, r, s')` |
| 环境层 | `env.py`, `sensor.py` | 加载地图、维护 belief map、模拟激光观测、计算奖励 |
| 图构建层 | `agent.py`, `node_manager.py`, `ground_truth_node_manager.py`, `utils.py`, `quads.py` | 从栅格地图中提 frontier、建图、生成 actor/critic 观测 |
| 神经网络层 | `model.py` | 用 attention 编码图，输出策略分布和 Q 值 |

如果按“谁驱动谁”的顺序来看，主调用链是：

```text
driver.py
  -> runner.py (Ray actor)
    -> worker.py
      -> env.py
      -> agent.py
        -> node_manager.py
        -> utils.py
      -> ground_truth_node_manager.py
      -> model.py
  -> 回到 driver.py
  -> 用 collected transitions 做 SAC 更新
```

---

## 4. 仓库顶层文件各自负责什么

### 4.1 `parameter.py`

统一定义训练、地图、图结构、网络和硬件相关参数。

最重要的几个参数：

- `CELL_SIZE = 0.4`
  - 地图栅格分辨率，单位米
- `NODE_RESOLUTION = 4.0`
  - 图节点之间的间隔
- `SENSOR_RANGE = 16`
  - 激光感知半径
- `UPDATING_MAP_SIZE = 4 * SENSOR_RANGE + 4 * NODE_RESOLUTION`
  - 每次围绕机器人截取的局部更新地图大小
- `K_SIZE = 25`
  - 每个节点最多保留的邻接候选数量
- `NODE_PADDING_SIZE = 360`
  - 为了 batch 训练，图节点数统一 pad 到 360
- `NUM_META_AGENT = 16`
  - Ray 并行 worker 数
- `MAX_EPISODE_STEP = 128`
  - 单个 episode 最大步数

这些参数决定了整个系统的时空分辨率和显存/内存开销。

### 4.2 `driver.py`

训练主入口，负责：

- 初始化全局 `PolicyNet`
- 初始化两个 `QNet`
- 初始化两个 target Q 网络
- 启动多个 Ray runner 并发采样
- 聚合 worker 收集回来的 episode 数据
- 维护 replay buffer
- 采样 batch 并执行 SAC 更新
- 定期写 TensorBoard
- 定期保存 checkpoint

这是全仓库的“主控程序”。

### 4.3 `runner.py`

Ray worker 的轻量包装层。

每个 `RLRunner` 持有一份本地策略网络权重。  
当 `driver.py` 下发最新策略参数后，`runner.py` 会创建一个 `Worker` 去跑一整个 episode。

它本身几乎不做算法，只负责：

- 接收权重
- 创建 `Worker`
- 返回 episode 经验和指标

### 4.4 `worker.py`

单个 episode 的执行器。

它把下面几件事串起来：

- `Env`：环境状态
- `Agent`：基于 belief graph 做动作选择
- `GroundTruthNodeManager`：给 critic 构造更完整的 ground-truth graph 观测

`worker.py` 是理解“单步交互发生了什么”的最好入口。

### 4.5 `env.py`

探索环境，负责：

- 从 `maps/` 中加载一张真实地图
- 初始化机器人 belief map
- 用激光模型不断更新 belief map
- 记录机器人位姿、累计路程、探索率
- 计算每一步 reward

### 4.6 `agent.py`

策略代理，负责：

- 根据当前 belief map 更新局部地图
- 提取 frontier
- 调用 `NodeManager` 更新 informative graph
- 生成 actor 的图观测
- 调用策略网络从邻居中采样下一步动作

可以把它理解为“belief graph 上的高层规划器”。

### 4.7 `node_manager.py`

belief graph 的构建与维护器。

职责包括：

- 生成局部更新区域内的候选图节点
- 为节点维护 utility
- 建立节点间可通行边
- 维护每个节点的 `neighbor_set`
- 提供 Dijkstra / A* 等辅助路径函数

这里的关键概念是：

- **节点**：一个可达的候选观测位置
- **utility**：从该节点能观察到多少 frontier
- **neighbor_set**：图上的局部连边

### 4.8 `ground_truth_node_manager.py`

这是当前仓库相对特殊的部分。

它基于**真实地图**构建完整自由空间图，但又把 actor 当前已经探索到的信息同步进去，从而生成 critic 使用的观测。

这样做的直觉是：

- actor 只能根据当前 belief 决策，符合真实探索约束
- critic 可以看得更全一些，更容易学到稳定的 Q 估计

这也是“ground truth critic”名称的来源。

### 4.9 `model.py`

定义两个核心网络：

- `PolicyNet`
- `QNet`

它们都基于 attention 结构：

- 编码器：多层 self-attention 处理整张图
- 解码器：聚焦当前节点
- 输出层：
  - `PolicyNet` 用 pointer attention 在邻居上输出动作分布
  - `QNet` 对每个邻居动作输出一个 Q 值

### 4.10 `utils.py`

各种基础工具函数，尤其重要的有：

- 坐标与栅格索引转换
- frontier 提取
- 更新区域内节点采样
- 可达连通域提取
- 碰撞检测
- GIF 保存

这些函数虽然分散，但实际上支撑了整套图构建过程。

### 4.11 `sensor.py`

用光线投射模拟 360 度激光雷达，把真实地图的信息一点点写入 belief map。

### 4.12 `quads.py`

第三方 `QuadTree` 实现，用来高效存储和查找图节点。

对项目理解来说，只需要知道：

- 节点不是简单放在 Python dict 里
- 而是存在四叉树中做空间索引

算法细节不是当前项目的重点。

---

## 5. 先建立几个核心概念

在看具体代码之前，先把项目里的几个关键词分清楚。

### 5.1 Ground Truth Map

真实地图，也就是环境的完整自由空间与障碍物信息。

- 在训练环境里，程序当然知道整张图
- 但 actor 不允许直接用它做决策

### 5.2 Belief Map

机器人当前“已经观测到”的地图。

初始时几乎全是未知区域，随着每次激光扫描逐步揭示。

### 5.3 Frontier

frontier 是“**已知自由区域和未知区域的边界**”。

探索任务里，frontier 通常代表：

> 如果机器人继续往这里看，很可能发现新的空间。

因此，frontier 是这里定义 utility 和 reward 的核心。

### 5.4 Informative Graph

在局部可达自由空间上抽样出来的一张图。

图中：

- 节点 = 候选观测位置
- 边 = 两节点之间无遮挡、可直接通行
- 节点 utility = 从该点可观察到多少 frontier

### 5.5 Actor Observation vs Critic Observation

这是本仓库最重要的设计之一。

**Actor observation**

- 来自 belief graph
- 只看当前已经探索到的部分
- 节点特征是 4 维

**Critic observation**

- 来自 ground-truth graph
- 图更完整
- 节点特征是 5 维

从代码上看：

- `PolicyNet(NODE_INPUT_DIM, EMBEDDING_DIM)`，其中 `NODE_INPUT_DIM = 4`
- `QNet(NODE_INPUT_DIM + 1, EMBEDDING_DIM)`，即输入 5 维

这个多出来的 1 维，本质上就是 critic 多看见的一些状态信息。

---

## 6. 一次 episode 从头到尾发生了什么

这部分是理解整个系统最关键的部分。

### 6.1 `driver.py` 启动训练

训练开始时，`driver.py` 会：

1. 初始化全局 actor 和 critic 网络
2. 初始化 target Q 网络
3. 启动 `NUM_META_AGENT` 个 Ray runner
4. 把当前策略权重下发给每个 runner
5. 让每个 runner 启动一个 episode

也就是说，训练是“**并行采样，中心化更新**”的结构。

### 6.2 `runner.py` 创建 `Worker`

每个 runner 收到权重后，会：

1. 把本地策略网络更新到最新权重
2. 创建一个 `Worker`
3. 调用 `worker.run_episode()`

这里注意：

- worker 端只需要策略网络
- Q 网络只存在于 `driver.py`
- 也就是说 worker 只是负责采样，不负责训练 critic

### 6.3 `Worker` 初始化环境与代理

`Worker` 初始化时创建三个对象：

- `Env`
- `Agent`
- `GroundTruthNodeManager`

分别对应：

- 环境状态
- actor 侧图构建与动作选择
- critic 侧 ground-truth 图构建

同时，`Worker` 还会初始化一个长度为 27 的 `episode_buffer`，用于保存 transition。

### 6.4 `Env` 加载地图并初始化 belief

`Env` 会从 `maps/` 中取一张 PNG 地图。

流程大致是：

1. 读取一张地图图像
2. 用 `block_reduce` 下采样
3. 找一个起始点标记
4. 把图像值转换成三类语义：
   - 自由
   - 障碍
   - 未知
5. 初始化 belief map 为全未知
6. 执行一次激光扫描，让机器人初始位置周围变成已知

此时环境里同时存在两张图：

- `ground_truth`
- `robot_belief`

### 6.5 episode 的第 0 步：构图并生成观测

在 episode 刚开始时，`Worker.run_episode()` 先做：

1. `robot.update_planning_state(self.env.belief_info, self.env.robot_location)`
2. `robot.get_observation()`
3. `ground_truth_node_manager.get_ground_truth_observation(...)`

这三步分别对应：

- 用 belief map 更新 actor 侧图结构
- 把 actor 侧图结构打包成网络输入
- 用 ground-truth 图打包 critic 输入

### 6.6 episode 循环：每一步做什么

随后进入 `for i in range(MAX_EPISODE_STEP)` 循环。

每次循环都做下面几件事。

#### 第一步：保存当前状态

`save_observation(observation, ground_truth_observation)`

把当前时刻的：

- actor observation
- critic observation

写进 `episode_buffer`。

#### 第二步：策略选择下一跳节点

`next_location, action_index = self.robot.select_next_waypoint(observation)`

这里不是输出速度，也不是输出栅格动作，而是：

- 在当前节点的邻居集合里采样一个动作
- 得到下一个图节点坐标 `next_location`

#### 第三步：环境执行一步

`reward = self.env.step(next_location)`

环境会做：

1. 机器人位置更新到 `next_location`
2. 基于新位置执行激光扫描
3. 更新 belief map
4. 更新累计路程
5. 更新探索率
6. 计算 reward

#### 第四步：重新构图

机器人走到新位置后，belief map 变了，所以图也要重新更新：

1. `robot.update_planning_state(...)`
2. `robot.get_observation()`
3. `ground_truth_node_manager.get_ground_truth_observation(...)`

#### 第五步：判断 episode 是否结束

如果 `self.robot.utility.sum() == 0`，说明：

- 当前图里所有节点 utility 都为 0
- 也就是看不到有价值的 frontier 了

此时：

- `done = True`
- 奖励额外 `+20`

#### 第六步：保存 `(a, r, done, s')`

本步动作、奖励、终止标志、下一状态被写入 `episode_buffer`。

直到：

- 找不到可继续探索的 frontier
- 或达到 `MAX_EPISODE_STEP`

episode 才结束。

---

## 7. `episode_buffer` 的 27 个槽位分别存了什么

这是理解训练数据格式最直接的一部分。

`Worker` 维护一个长度为 27 的列表，每个下标保存一种张量序列。

| 下标 | 内容 |
|---|---|
| 0 | actor 当前 `node_inputs` |
| 1 | actor 当前 `node_padding_mask` |
| 2 | actor 当前 `edge_mask` |
| 3 | actor 当前 `current_index` |
| 4 | actor 当前 `current_edge` |
| 5 | actor 当前 `edge_padding_mask` |
| 6 | `action` |
| 7 | `reward` |
| 8 | `done` |
| 9 | actor 下一时刻 `node_inputs` |
| 10 | actor 下一时刻 `node_padding_mask` |
| 11 | actor 下一时刻 `edge_mask` |
| 12 | actor 下一时刻 `current_index` |
| 13 | actor 下一时刻 `current_edge` |
| 14 | actor 下一时刻 `edge_padding_mask` |
| 15 | critic 当前 `node_inputs` |
| 16 | critic 当前 `node_padding_mask` |
| 17 | critic 当前 `edge_mask` |
| 18 | critic 当前 `current_index` |
| 19 | critic 当前 `current_edge` |
| 20 | critic 当前 `edge_padding_mask` |
| 21 | critic 下一时刻 `node_inputs` |
| 22 | critic 下一时刻 `node_padding_mask` |
| 23 | critic 下一时刻 `edge_mask` |
| 24 | critic 下一时刻 `current_index` |
| 25 | critic 下一时刻 `current_edge` |
| 26 | critic 下一时刻 `edge_padding_mask` |

这就是为什么 `driver.py` 里会先初始化：

```python
experience_buffer = []
for i in range(27):
    experience_buffer.append([])
```

---

## 8. belief graph 是怎么构建出来的

这部分主要发生在 `agent.py` 和 `node_manager.py`。

### 8.1 先截取机器人周围的局部更新地图

`Agent.get_updating_map()` 会围绕机器人当前位置裁一个局部区域。

这样做的目的不是只保留局部视野，而是：

- 节点和 frontier 的更新只需要发生在当前可能受新观测影响的区域内
- 没必要每一步都在整张大地图上重建全部图结构

这个局部区域大小由 `UPDATING_MAP_SIZE` 决定。

### 8.2 在局部可达自由空间上采样图节点

`utils.get_updating_node_coords()` 会：

1. 按 `NODE_RESOLUTION` 在局部窗口里规则采样候选点
2. 提取与机器人当前位置连通的自由区域
3. 只保留落在这个连通自由区域里的节点

这一步很关键，因为它保证：

- 图节点只落在可达区域里
- 不会把障碍物另一侧的自由区误当成可直接到达

### 8.3 提取 frontier

`utils.get_frontier_in_map()` 会从当前 belief map 中找 frontier。

它的判断逻辑可以概括为：

- 当前格子必须是自由格
- 这个格子周围必须挨着未知格
- 但又不能是完全被未知包围的异常边界

然后，如果 `FRONTIER_CELL_SIZE != CELL_SIZE`，还会做一次降采样。

### 8.4 给每个节点计算 utility

节点 utility 定义在 `Node.initialize_observable_frontiers()` 中。

逻辑是：

1. 找出离该节点足够近的 frontier
2. 检查节点到 frontier 之间是否无遮挡
3. 满足条件的 frontier 放进 `observable_frontiers`
4. `utility = len(observable_frontiers)`
5. 如果 utility 太小，小于等于 `MIN_UTILITY`，直接置 0

所以这里的 utility 可以理解为：

> “站在这个图节点上，理论上能看到多少有价值的 frontier”

### 8.5 建立节点之间的边

节点连边逻辑在 `Node.update_neighbor_nodes()` 里。

它会在以当前节点为中心的一个 `5 x 5` 邻域模板中，尝试连接其他可能存在的节点。

判断规则是：

- 目标邻居节点必须存在
- 两点间连线不能穿过障碍或未知区域

如果满足，就互相写入 `neighbor_set`。

### 8.6 为什么 `neighbor_set` 里包含自己

每个节点初始化时，都会先把自己加入 `neighbor_set`。

这是一个实现技巧：

- 便于统一构造邻接结构
- 但动作选择时并不允许“原地不动”

因为在 `Agent.get_observation()` 里，当前节点对应的 self-edge 会被专门 mask 掉。

所以：

- 图结构里“自己是自己的邻居”
- 但策略输出时这个动作会被屏蔽

---

## 9. actor observation 是如何打包的

actor 的观测由 `Agent.get_observation()` 构造。

### 9.1 节点特征

belief graph 中每个节点的特征是 4 维：

```text
[dx, dy, utility, visited]
```

其中：

- `dx, dy`
  - 节点相对于当前机器人节点的坐标偏移
  - 再按 `UPDATING_MAP_SIZE` 归一化
- `utility`
  - 节点能观测到的 frontier 数量
  - 再做尺度归一化
- `visited`
  - 节点是否访问过

### 9.2 图结构相关张量

actor 观测一共由 6 个张量组成：

1. `node_inputs`
2. `node_padding_mask`
3. `edge_mask`
4. `current_index`
5. `current_edge`
6. `edge_padding_mask`

其含义如下。

#### `node_inputs`

形状大致为：

```text
[1, NODE_PADDING_SIZE, 4]
```

真实节点数不足 `NODE_PADDING_SIZE` 时，会在后面补零。

#### `node_padding_mask`

标记哪些节点位置是 padding。

- 真节点位置为 0
- padding 位置为 1

供 attention 层忽略补零节点。

#### `edge_mask`

图的邻接 mask。

代码里用的是：

- 可连通位置为 0
- 不可连通位置为 1

所以它本质上是 attention 的禁止连接掩码。

#### `current_index`

当前机器人所在节点在节点列表中的索引。

#### `current_edge`

当前节点的邻居索引列表，再 pad 到固定长度 `K_SIZE`。

策略最终只在这些邻居上做选择。

#### `edge_padding_mask`

标记当前可选动作里的无效位置。

这里同时承担两个作用：

- mask 掉 `current_edge` 中 pad 出来的部分
- mask 掉“当前节点自己”这个 self-edge

因此，真正可选的动作只剩“其他邻居节点”。

---

## 10. critic observation 为什么不一样

critic 观测由 `GroundTruthNodeManager.get_ground_truth_observation()` 构造。

它的核心思想是：

1. 启动时先在**完整真实地图**上生成整张 ground-truth 图
2. 每一步把 actor 当前已经探索到的节点状态同步进去
3. 构造一个“更完整、更接近全局真实环境”的图给 critic

### 10.1 这张 ground-truth 图是怎么来的

初始化时：

- 在整张 ground-truth map 上按 `NODE_RESOLUTION` 采样节点
- 只保留真实自由空间中的节点
- 基于真实地图建立所有可通行边

因此 critic 侧图从一开始就更完整。

### 10.2 每一步如何同步 actor 的探索状态

`update_graph()` 会遍历 actor 当前 belief graph 中已有节点，并把这些信息同步给 ground-truth 图中对应节点：

- `utility`
- `explored`
- `visited`

所以 critic 图既包含：

- 已探索区域的真实状态
- 也保留大量尚未探索但真实存在的自由空间节点

### 10.3 critic 的动作集合为什么仍与 actor 对齐

虽然 critic 图更完整，但动作集合没有完全放开。

当前节点的 `neighbor_indices` 不是直接从 critic 自己的邻接矩阵里取，而是：

- 先看 actor 当前 belief graph 中这个节点有哪些邻居
- 再在 critic 节点列表里找到这些邻居对应的索引

这样保证：

- actor 和 critic 评估的是同一组候选动作
- 只是 critic 对图状态知道得更多

### 10.4 critic 节点特征

critic 的 `node_inputs` 是 5 维：

```text
[dx, dy, utility, explored, visited]
```

这也是 `QNet` 输入维度比 `PolicyNet` 多 1 的原因。

---

## 11. 网络结构到底在做什么

`model.py` 里的网络结构看起来稍复杂，但逻辑其实很清楚。

### 11.1 `PolicyNet`

`PolicyNet` 做三件事。

#### 第一步：编码整张图

先把每个节点特征线性映射到 `EMBEDDING_DIM`，再经过多层 encoder attention。

目的：

- 让每个节点表征不仅包含自己的属性
- 也融合整张图的上下文信息

#### 第二步：聚焦当前节点

取出当前节点的特征后，再用 decoder 对整张图做一次条件注意力。

目的：

- 得到“以当前节点为中心”的状态表示

#### 第三步：只在邻居上输出策略

最后不在所有节点上输出概率，而是只拿当前节点的邻居特征，用 pointer attention 输出：

```text
log p(a | s)
```

这使得动作空间天然受图结构约束。

### 11.2 `QNet`

`QNet` 的结构前半段与 `PolicyNet` 非常接近：

- 先编码整张图
- 再抽取当前节点表示

区别在输出阶段：

- 对当前状态特征和每个邻居特征做拼接
- 对每个候选邻居输出一个标量 Q 值

因此，`QNet` 的输出形状大致是：

```text
[batch, K_SIZE, 1]
```

### 11.3 为什么这里像 Transformer

因为它本质上确实借用了 Transformer 的几个核心部件：

- Multi-head attention
- LayerNorm
- FeedForward
- Encoder/Decoder 结构

但它不是标准 NLP Transformer，而是一个**面向图结构决策的 attention 网络**。

---

## 12. `driver.py` 里的 SAC 训练逻辑

这一部分是项目的训练核心。

### 12.1 并行采样，集中训练

`driver.py` 会不断做这个循环：

1. 等待任意一个 Ray worker 完成 episode
2. 拿回 episode 数据
3. 塞进 replay buffer
4. 立刻给这个空出来的 worker 派新任务
5. 如果 buffer 足够大，就执行若干次梯度更新

所以采样和训练是交织进行的。

### 12.2 replay buffer 的组织方式

这里没有定义复杂的 replay buffer 类，而是直接用一个长度为 27 的 Python 列表。

每个元素又是一个 list，用于保存某一种字段在所有 transition 上的样本。

这种实现不优雅，但非常直接：

- 采样时对每个字段按相同索引取 batch
- 再用 `torch.stack` 拼起来

### 12.3 policy loss

代码里 policy loss 的逻辑是典型的离散动作 SAC：

1. 用 actor 计算每个候选动作的 `logp`
2. 用两个 critic 取最小值作为 Q
3. 优化：

```text
E_a [ alpha * log pi(a|s) - Q(s,a) ]
```

这里 actor 用的是 belief observation，critic 用的是 ground-truth observation。

### 12.4 target Q

下一时刻目标值用 target critic 网络计算：

```text
target_q = reward + gamma * (1 - done) * V(next_state)
```

其中：

```text
V(next_state) = E_a [ Q_target(next_state, a) - alpha * log pi(a|next_state) ]
```

### 12.5 Q 网络更新

两个 Q 网络各自回归同一个 `target_q`。

这样做是双 Q 结构，目的是减少过估计。

### 12.6 alpha 自动调节

`log_alpha` 是可学习参数。

代码会根据当前策略熵和目标熵之间的差异来更新它，从而自动调节探索强度。

目标熵由：

```python
entropy_target = 0.05 * (-np.log(1 / K_SIZE))
```

给出。

### 12.7 target 网络更新

当前实现不是每步软更新，而是每累计一定次数后直接把主 Q 网络拷贝给 target Q 网络。

这是一种相对简单的 target 更新方式。

### 12.8 日志与模型保存

`driver.py` 还会：

- 每 `SUMMARY_WINDOW` 次写一次 TensorBoard
- 每 32 个 episode 存一次 checkpoint

因此训练输出主要在：

- `train/...`
- `model/...`
- `gifs/...`

---

## 13. reward 到底鼓励了什么

reward 在 `Env.calculate_reward()` 中定义，核心上只有两部分。

### 13.1 距离惩罚

```text
reward -= dist / UPDATING_MAP_SIZE * 5
```

走得越远，惩罚越大。

它鼓励：

- 不要无意义绕路
- 尽量在较短距离内换来更多探索收益

### 13.2 frontier 收益

reward 会根据“本步新消掉了多少旧 frontier”增加。

直观上就是：

- 如果这一步观测让许多 frontier 消失，说明你看到了很多新空间
- 这一步应该得到正奖励

### 13.3 终止 bonus

当整张图里已经没有 utility 大于 0 的节点时，worker 会给额外 `+20`。

这鼓励策略尽快把环境探索干净。

---

## 14. 代码实现里几个很关键的设计点

### 14.1 训练时是“跳点”而不是连续导航

`env.step(next_waypoint)` 直接把机器人位置更新到下一节点。

这意味着：

- 当前框架学习的是高层 exploration policy
- 不是完整的局部路径跟踪或运动控制器

### 14.2 graph 比直接像素动作更结构化

如果在整张网格图上直接选动作，状态空间太大。

这里先做图抽象后有几个好处：

- 动作空间缩小
- 更容易表达拓扑结构
- 更接近探索问题本质

### 14.3 actor 和 critic 信息不对称

这是该实现最特别的一点：

- actor：受现实约束，只看 belief
- critic：看得更全，更容易评估长期价值

这是一种“训练时更强、执行时更弱”的设定。

### 14.4 图是动态更新的，不是静态地图一次建完

belief graph 每走一步都会更新。

因为：

- frontier 会变化
- 可观测 utility 会变化
- 新区域被看见后，节点及连边也会继续扩展

所以策略面对的是一张不断变化的图。

### 14.5 固定 padding 是为了 batch 训练

不同 episode、不同时间步的图节点数和邻居数都不同。

为了能放进同一个 batch 里训练，代码把：

- 节点数 pad 到 `NODE_PADDING_SIZE`
- 邻居数 pad 到 `K_SIZE`

这也是各种 `mask` 存在的原因。

---

## 15. 如果你要顺着源码读，建议顺序如下

建议按下面顺序阅读。

### 第一轮：建立全局认识

1. `README.md`
2. `parameter.py`
3. `driver.py`

目标是先知道：

- 怎么启动训练
- 整体框架是什么
- 核心超参数有哪些

### 第二轮：理解单个 episode

1. `worker.py`
2. `env.py`
3. `agent.py`

目标是知道：

- 单个 episode 怎么跑
- 每一步状态怎么更新
- 动作怎么产生

### 第三轮：理解图构建

1. `node_manager.py`
2. `ground_truth_node_manager.py`
3. `utils.py`

目标是搞清楚：

- 节点从哪来
- utility 怎么算
- 边怎么连
- critic 为什么和 actor 看到的不一样

### 第四轮：理解网络和训练

1. `model.py`
2. 再回看 `driver.py` 的训练部分

目标是搞清楚：

- 图张量怎么喂进网络
- actor 和 critic 的 loss 分别如何计算

---

## 16. 几个容易忽略但值得知道的实现细节

### 16.1 worker 端只同步 policy，不同步 Q 网络

这是因为：

- worker 的任务只是采样动作
- 训练只在 driver 中进行

因此并发端负担较小。

### 16.2 地图切换是按 episode 编号取模

每个 episode 会根据 `episode_index % len(map_list)` 选择地图。

这意味着训练会不断轮换地图，但地图顺序受 `os.listdir()` 返回结果影响。

### 16.3 默认配置对资源要求不低

README 写得很直接：

- 约 8GB VRAM
- 约 20GB RAM

因为：

- worker 数多
- 图输入 pad 较大
- replay buffer 在 Python list 里堆积

### 16.4 `GAMMA = 1`

这里的折扣因子设为 1，说明作者更偏向把探索问题当成近似有限时域的“总收益最大化”任务，而不是强调短期折扣。

### 16.5 `GroundTruthNodeManager` 是本实现的关键差异点

如果没有这一层，这个仓库就更像普通的基于 belief graph 的 SAC 探索。

有了它之后，critic 的输入分布和 actor 明显不同，这是阅读时必须持续记住的前提。

---

## 17. 可以把整个项目压缩成一张心智图

如果只保留最核心的逻辑，可以把项目记成下面这段话：

```text
环境里有一张真实地图，但机器人一开始不知道。
机器人每走一步，就用激光把周围未知区域揭开一点。
程序把当前已知区域抽象成一张图：
  节点表示可去的位置，
  utility 表示从那里能看到多少 frontier，
  边表示两点之间可以直接通行。
策略网络不直接看像素，而是在图上选“下一个邻居节点”。
worker 并行跑很多 episode 收集经验，driver 用 SAC 更新策略和价值网络。
其中 actor 用 belief graph，critic 用 ground-truth graph。
```

如果你已经接受了这段话，整个仓库的大方向就基本清楚了。

---

## 18. 后续如果要继续深入，建议优先回答的几个问题

如果后面要继续研究或改代码，最值得继续往下挖的是下面这些问题：

1. `GroundTruthNodeManager` 这种 critic 设计，具体比普通 belief critic 稳定多少？
2. `NODE_RESOLUTION`、`K_SIZE`、`NODE_PADDING_SIZE` 对性能和资源占用的影响有多大？
3. 训练时“跳点”的高层策略，迁移到真实 ROS 导航时损失有多大？
4. reward 中 frontier 收益和距离惩罚的相对权重是否合适？
5. 图节点 utility 为 0 后就不再继续扩邻居，这个剪枝会不会影响远距离结构表达？

这些问题都已经超出“看懂代码”的范围，但会直接决定你后续怎么改这个项目。

---

## 19. 总结

这个项目不是一个传统意义上的端到端像素强化学习，而是一个**图抽象 + attention 策略 + SAC 训练**的探索框架。

它最关键的三条主线是：

1. **环境主线**
   - 真实地图 -> belief map -> frontier -> reward
2. **图主线**
   - belief map -> informative graph -> actor observation
   - ground truth map -> ground-truth graph -> critic observation
3. **训练主线**
   - 并行 worker 采样 -> replay buffer -> SAC 更新 actor/critic

只要把这三条线串起来，这个仓库的代码组织其实是比较清晰的。

