# ARiADNE 三步走落地教学文档

**目标**：按照下面这条路线，从“先验证官方效果”到“接入你自己的链路”再到“必要时微调训练”，逐步把 ARiADNE 用起来。

> 1. 先拉 `ARiADNE-ROS-Planner` 的 `humble` 分支，用自带 checkpoint 在它自己的 Gazebo 环境里跑起来。  
> 2. 再把它接到你当前 Unity/实机链路里，保留 `sensor_scan_generation`、`terrain_analysis`、`localPlanner`，只替换 `TARE -> /way_point` 这一层。  
> 3. 只有当预训练模型方向对、但你场景表现不够好时，再回头用 `large-scale-DRL-exploration` 做微调训练。

这份文档的写法偏“教学”和“落地”，不是学术总结。

---

## 0. 先说明你当前最合理的策略

你现在并不缺“一个更复杂的训练项目”，你缺的是：

1. 一个能尽快看到 DRL 探索效果的入口
2. 一个能最低风险接到你当前系统里的方案
3. 一个只有在必要时才启动的大训练任务

因此，最正确的顺序不是：

- 先读完所有代码
- 先学会所有 DRL 理论
- 先自己训一个模型

而是：

- 先跑通官方预训练 ROS2 版
- 再试接你自己的链路
- 最后才考虑重训练

---

## 1. Step 1：先跑 `ARiADNE-ROS-Planner` 的 `humble` 分支

这一步的目标很简单：

> 不管你自己的 Unity/实机系统先怎样，先确认作者提供的 ROS2 版 ARiADNE 能跑、能出 waypoint、能完成探索。

如果这一步没过，后面接到你自己的系统里只会更难排错。

### 1.1 为什么先跑官方 ROS planner，而不是先跑训练仓库

因为你当前真正要评估的是：

- 这个方法作为“探索模块”是否可用
- 它是否能稳定输出 `/way_point`
- 它在 ROS2 场景下部署是否顺畅

而这些问题，`ARiADNE-ROS-Planner` 比 `large-scale-DRL-exploration` 更直接回答。

训练仓库更适合在以下场景再用：

- 预训练模型方向对，但你场景不适配
- 你确认值得投入训练资源

### 1.2 推荐的目录组织

建议不要一开始就把 `ARiADNE-ROS-Planner` 塞进你现在的 `autonomy_stack` 工作区。

更低风险的做法是：

```bash
mkdir -p /home/liuyi/projects/thermal_nav/ariadne_ros_ws/src
cd /home/liuyi/projects/thermal_nav/ariadne_ros_ws/src
git clone -b humble https://github.com/marmotlab/ARiADNE-ROS-Planner.git
```

这样做的好处是：

- 你可以单独编译、单独验证
- 不会污染你当前已经能跑的工作区
- 排错时边界更清楚

### 1.3 先决条件

至少需要：

- Ubuntu 22.04
- ROS2 Humble
- `octomap_server`
- Python 依赖：`torch`、`scikit-image`、`rospkg`

官方 `humble` 分支 README 推荐的关键包是：

```bash
sudo apt-get install ros-humble-octomap-server
```

Python 侧如果你打算跟 ROS2 系统 Python 混用，最省事的方式通常是直接在当前 Python 环境里安装：

```bash
pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu
pip install scikit-image rospkg
```

如果你更喜欢 conda，也可以，但 ROS2 + conda 的坑会更多一些。

### 1.4 编译 `humble` 分支

```bash
source /opt/ros/humble/setup.bash
cd /home/liuyi/projects/thermal_nav/ariadne_ros_ws
python -m colcon build
source install/setup.bash
```

### 1.5 为什么说它自带 checkpoint

`humble` 分支里 `setup.py` 会把 `rl_planner/model/*` 安装到 share 目录，代码运行时会从安装后的 `model/checkpoint.pth` 读取策略权重。

所以默认情况下：

- 不需要你先训练
- 不需要你先手动下载额外模型

### 1.6 官方运行方式

官方 README 推荐的思路是：

1. 先启动 CMU 的 Gazebo development environment
2. 再启动 `rl_planner`

文档里给的命令形式是：

```bash
source install/setup.bash
ros2 launch vehicle_simulator system_indoor.launch
```

然后再开另一个终端：

```bash
source install/setup.bash
ros2 launch rl_planner rl_planner.launch.py
```

### 1.7 这一步你要观察什么

不要一上来只盯着 RViz 看“像不像在跑”。

更应该看下面这些可检查项。

#### 话题层面

至少要确认：

- `/projected_map`
- `/state_estimation`
- `/way_point`
- `/runtime`

其中最重要的是：

- `/way_point` 是否持续更新
- `/runtime` 是否稳定，说明 planner 在循环工作

#### 逻辑层面

你要确认：

- 机器人不是原地抖动
- waypoint 在地图上是向未知区域推进的
- 探索过程不是明显来回 oscillation

#### 性能层面

先不要追求最优。

只要：

- 能稳定完成探索
- 规划频率合理
- 不出现频繁死循环

就说明 Step 1 合格。

### 1.8 如果你是无头服务器怎么办

官方 launch 默认会启动 RViz。

如果你在无头服务器上验证，有两个做法。

#### 做法 A：临时改 launch，去掉 RViz

复制一份 launch，把 `rviz_node` 去掉。

这是最干净的做法。

#### 做法 B：不走 launch，一次性手动起两个节点

你可以只起：

- `octomap_server_node`
- `rl_planner`

这样就不依赖图形界面。

### 1.9 Step 1 常见问题

#### 问题 1：`rl_planner` 起不来

先检查：

- `checkpoint.pth` 是否安装到了 `share/rl_planner/model/`
- Python 依赖是否安装完整
- 是否 source 了 `install/setup.bash`

#### 问题 2：有 `/state_estimation`，但没有 `/way_point`

先检查：

- `/projected_map` 是否存在
- `octomap_server` 是否正常吃到点云
- TF 是否正常

#### 问题 3：能出 waypoint，但不动

这通常不是 ARiADNE 的问题，而是：

- waypoint follower
- local planner
- 运动底盘链路

### 1.10 Step 1 的通过标准

只有满足下面三点，才进入 Step 2：

1. 官方 `humble` 分支能稳定跑起来
2. 自带 checkpoint 能持续输出合理 `/way_point`
3. 至少在官方 Gazebo 场景里能完成探索

---

## 2. Step 2：把 ARiADNE 接到你当前 Unity / 实机链路

这一阶段的目标是：

> 不改你的底层导航，不改 SLAM，不改局部避障，只把“探索目标点生成器”从 TARE 换成 ARiADNE。

这一步最关键的思想是：

- 你不是在换整个 autonomy stack
- 你是在换 `/way_point` 的上游

### 2.1 你当前链路里哪些保留，哪些替换

建议保留：

- `FAST-LIO2`
- `registered_scan_frame_relay`
- `odom_frame_relay`
- `sensor_scan_generation`
- `terrain_analysis`
- `localPlanner`
- `pathFollower`

可以保留但不是 ARiADNE 必需：

- `terrain_analysis_ext`
- `visualization_tools`
- RViz

要替换的只有：

- `tare_planner_node`

### 2.2 为什么 `terrain_analysis` 还要保留

因为 ARiADNE 本身不负责局部碰撞规避。

在你当前系统里：

- `localPlanner` 仍然依赖 `/terrain_map` 和 `/registered_scan`
- `pathFollower` 仍然依赖 `localPlanner` 输出路径

也就是说：

- ARiADNE 只负责“去哪里”
- `terrain_analysis + localPlanner` 仍然负责“怎么安全地过去”

这是整个最小替换方案成立的根本。

### 2.3 当前系统 vs 接入后系统的数据流

你当前 TARE 版本大致是：

```text
/state_estimation + /registered_scan
  -> sensor_scan_generation
  -> /sensor_scan + /state_estimation_at_scan

/registered_scan
  -> terrain_analysis
  -> /terrain_map

/terrain_map + /terrain_map_ext + /state_estimation_at_scan + /registered_scan
  -> TARE
  -> /way_point
  -> localPlanner
  -> /path
  -> pathFollower
  -> /cmd_vel
```

接 ARiADNE 后建议变成：

```text
/state_estimation + /registered_scan
  -> sensor_scan_generation
  -> /sensor_scan + /state_estimation_at_scan

/registered_scan
  -> terrain_analysis
  -> /terrain_map

/sensor_scan
  -> octomap_server
  -> /projected_map

/projected_map + /state_estimation
  -> ARiADNE rl_planner
  -> /way_point
  -> localPlanner
  -> /path
  -> pathFollower
  -> /cmd_vel
```

### 2.4 这一步最容易被忽略的关键点：`base_frame`

这是接入时最容易踩坑的一点。

`ARiADNE-ROS-Planner` 的官方 launch 默认：

- `base_frame = sensor`

但你当前 `sensor_scan_generation` 发布的 `/sensor_scan`，其 `frame_id` 是：

- `sensor_at_scan`

因此，如果你直接照搬官方 launch，很可能会卡在 TF 或地图构建上。

所以在你当前系统里，最保守的做法是：

- 把 ARiADNE launch 中 `base_frame` 从 `sensor` 改为 `sensor_at_scan`

这是接入成功的关键参数之一。

### 2.5 Step 2 的推荐做法

不要一上来改一堆代码。

先按下面顺序做。

#### 子步骤 A：单独把 `octomap_server` 接进你当前系统

先只做：

- 输入 `/sensor_scan`
- 输出 `/projected_map`

验证项：

- `/projected_map` 持续有数据
- RViz 中 occupancy map 合理
- 没有明显 frame 错位

#### 子步骤 B：再单独起 `rl_planner`

此时先不要关心是否能跑完全流程，只关心：

- `rl_planner` 是否吃到 `/projected_map`
- 是否吃到 `/state_estimation`
- 是否开始发 `/way_point`

#### 子步骤 C：再接回 `localPlanner`

当 `/way_point` 正常后，再观察：

- localPlanner 是否稳定吃到目标点
- `/path` 是否连续更新
- `/cmd_vel` 是否正常

### 2.6 Step 2 的验证顺序

建议顺序是：

1. Unity 仿真里验证
2. bag 回放验证
3. 再上实机

不要反过来。

### 2.7 Unity 仿真里你该重点看什么

不是先看是否“完成探索”，而是先看链路是否对：

1. `/sensor_scan` 是否正常
2. `/projected_map` 是否正常
3. `/way_point` 是否持续产生
4. `localPlanner` 是否能跟上这些 waypoint
5. 是否出现明显 waypoint 振荡

### 2.8 实机前一定要先解决的两个问题

#### 问题 1：Waypoint 间距与 local planner 跟踪能力是否匹配

ARiADNE 输出的 waypoint 可能更“跳跃式”。

如果：

- `localPlanner` 的到点阈值太小
- 或 `ARiADNE` 的 `next_waypoint_threshold` 太激进

就可能出现：

- waypoint 合理，但底层跟踪体验差

#### 问题 2：投影地图质量是否足够

ARiADNE 依赖 occupancy grid。

如果：

- `/sensor_scan` 噪声大
- Octomap 参数不合适
- `projected_map` 破碎或膨胀严重

高层探索策略再好也会被输入质量拖垮。

### 2.9 Step 2 的通过标准

只有满足下面三点，才建议进入 Step 3：

1. 在 Unity / bag / 实机中，ARiADNE 能稳定接管 `/way_point`
2. 你能观察到它在室内场景里的探索风格与 TARE 明显不同
3. 你确认问题主要出在“策略适配不足”，而不是链路或地图质量

---

## 3. Step 3：只有在必要时，才用 `large-scale-DRL-exploration` 微调训练

这一步是最贵的，不该最先做。

它只在以下条件下启动：

1. Step 1 成功
2. Step 2 也成功
3. 但你发现预训练模型在你自己的走廊/室内分布里表现不够好

如果问题其实是：

- TF 错位
- occupancy map 质量差
- localPlanner 跟踪不住

那训练新模型通常不能解决根本问题。

### 3.1 什么时候说明真的需要微调

下面这些现象，更像“需要训练适配”：

- 官方 Gazebo 效果不错，但你自己的室内走廊场景表现持续差
- 地图和输入都正确，但策略总是犹豫或绕远
- 在岔路口、窄通道、长走廊中行为和论文直觉不一致

### 3.2 微调的目标不一定是“从零训练”

更建议：

- 从已有 checkpoint 继续训练
- 或用更贴近你场景的地图继续训练

比从头训更现实。

### 3.3 你最应该改的不是网络，而是训练场景分布

如果你的真实环境是：

- 窄走廊
- T 型 / 十字岔路
- 房间连走廊

那最有价值的不是先改模型结构，而是：

1. 用这些结构做更多训练地图
2. 再在现有 checkpoint 上做 domain adaptation

### 3.4 微调时最该关注哪些参数

在 `large-scale-DRL-exploration` 里，最值得关注的是：

- `NODE_RESOLUTION`
- `SENSOR_RANGE`
- `K_SIZE`
- `NODE_PADDING_SIZE`
- `NUM_META_AGENT`

其中：

- `NODE_RESOLUTION` 影响图稀疏程度和拓扑表达
- `SENSOR_RANGE` 影响 frontier utility 和局部地图大小
- `NUM_META_AGENT` 直接影响内存/CPU 开销

### 3.5 训练资源预期

当前仓库 README 写得比较明确：

- 默认训练大约需要 8GB VRAM
- 大约需要 20GB RAM

因此：

- 有条件的话，用实验室服务器
- 没必要先在本地死磕大训练

### 3.6 训练完成后怎么给 ROS planner 用

训练产物核心是 checkpoint。

部署时的基本思路是：

1. 训练得到新的 `checkpoint.pth`
2. 替换 `ARiADNE-ROS-Planner` 安装目录中的模型文件
3. 再重新跑 `rl_planner`

也就是说：

- 训练和 ROS 部署是分离的
- ROS planner 本质上只是推理壳

---

## 4. 三步走的决策门槛总结

### 什么时候停在 Step 1

如果你连官方 `humble` 版都没跑通，就不要急着接入自己的系统。

### 什么时候进入 Step 2

只有当你确认：

- 官方预训练模型能稳定工作
- ROS2 部署链路没有本质问题

才值得接入你自己的 Unity / 实机系统。

### 什么时候进入 Step 3

只有当你已经证明：

- 链路通了
- 预训练模型方向对
- 但场景分布仍不匹配

才值得投入训练资源。

---

## 5. 我对你当前最实际的建议

如果你问“现在马上该做什么”，我的建议是：

1. 先读论文细读文档，确认方法主线
2. 把 `ARiADNE-ROS-Planner` `humble` 分支独立拉起来
3. 验证 `/projected_map -> /way_point` 这一段
4. 再准备接进你现有 `autonomy_stack`

这样做最节省时间，也最符合工程排错顺序。

