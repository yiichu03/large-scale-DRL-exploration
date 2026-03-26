# 2D 运行复现与结果记录

本文档记录我在本机对 `large-scale-DRL-exploration` 做 2D 验证时实际使用过的命令、输出结果和注意事项，目标是让后续复现尽量不依赖聊天记录。

## 1. 本次验证结论

- 当前仓库在本机已经可以正常跑 2D episode。
- 为了兼容当前环境的 `NumPy 2.x`，我修了两处代码：
  - `sensor.py`
  - `utils.py`
- 修复提交是：`44e0ca9`  
  提交信息：`fix: support numpy 2 in 2d exploration smoke test`
- 当前仓库里没有自带 checkpoint。
- 但本机 `ARiADNE-ROS-Planner` 里的预训练权重可以直接加载到当前仓库里跑 2D episode。

## 2. 运行环境

- 仓库路径：`/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration`
- `conda` 路径：`/home/liuyi/miniforge3/bin/conda`
- 使用环境：`ros2-torch`
- 运行时为了避免 matplotlib 写入家目录失败，额外设置：
  - `MPLCONFIGDIR=/tmp/mplconfig_ls_drl`

推荐每次先执行：

```bash
cd /home/liuyi/projects/thermal_nav/large-scale-DRL-exploration
source /home/liuyi/miniforge3/etc/profile.d/conda.sh
conda activate ros2-torch
export MPLCONFIGDIR=/tmp/mplconfig_ls_drl
```

## 3. 确认本机预训练权重位置

命令：

```bash
find /home/liuyi/projects/thermal_nav/ARiADNE-ROS-Planner -name 'checkpoint.pth' -o -name '*.pth'
```

本机输出：

```text
/home/liuyi/projects/thermal_nav/ARiADNE-ROS-Planner/src/rl_planner/rl_planner/model/checkpoint.pth
/home/liuyi/projects/thermal_nav/ARiADNE-ROS-Planner/install/rl_planner/share/rl_planner/model/checkpoint.pth
```

下面的实验统一使用：

```text
/home/liuyi/projects/thermal_nav/ARiADNE-ROS-Planner/src/rl_planner/rl_planner/model/checkpoint.pth
```

## 4. 随机初始化策略的 2D smoke test

目的：

- 验证当前仓库代码链路能否完整跑完一个 episode
- 这个实验不用于判断算法效果

命令：

```bash
python - <<'PY'
import torch
import numpy as np
from model import PolicyNet
from worker import Worker
from parameter import NODE_INPUT_DIM, EMBEDDING_DIM

torch.manual_seed(4777)
np.random.seed(4777)
model = PolicyNet(NODE_INPUT_DIM, EMBEDDING_DIM)
worker = Worker(0, model, 77, save_image=False)
worker.run_episode()
print(worker.perf_metrics)
print('steps', len(worker.episode_buffer[6]))
PY
```

本机输出：

```text
{'travel_dist': np.float64(885.1596489727087), 'explored_rate': np.float64(0.7454473920863309), 'success_rate': False}
steps 128
```

解释：

- `success_rate=False` 说明没有在 `MAX_EPISODE_STEP=128` 之内完成探索
- 但这个实验已经足够说明当前 2D 环境、图构建、策略前向和 episode 循环都能跑通

## 5. 单次加载预训练 checkpoint 的 2D 测试

目的：

- 验证 `ARiADNE-ROS-Planner` 的 checkpoint 能否直接用于当前 2D 仓库
- 初步判断预训练模型是否明显优于随机策略

命令：

```bash
python - <<'PY'
import torch
import numpy as np
from model import PolicyNet
from worker import Worker
from parameter import NODE_INPUT_DIM, EMBEDDING_DIM

ckpt_path = '/home/liuyi/projects/thermal_nav/ARiADNE-ROS-Planner/src/rl_planner/rl_planner/model/checkpoint.pth'

torch.manual_seed(4777)
np.random.seed(4777)
model = PolicyNet(NODE_INPUT_DIM, EMBEDDING_DIM)
checkpoint = torch.load(ckpt_path, map_location='cpu')
model.load_state_dict(checkpoint['policy_model'])
worker = Worker(0, model, 77, save_image=False)
worker.run_episode()
print(worker.perf_metrics)
print('steps', len(worker.episode_buffer[6]))
PY
```

本机输出：

```text
{'travel_dist': np.float64(332.61238775440677), 'explored_rate': np.float64(1.0), 'success_rate': True}
steps 55
```

解释：

- 这说明当前训练仓库和 `ARiADNE-ROS-Planner` 的权重格式是兼容的
- 同样的 `episode_index=77`，预训练策略明显优于随机初始化策略

## 6. 5 张地图的快速初测

目的：

- 不停留在单张图上
- 粗略看一下预训练模型在几个不同 episode 上是否稳定

命令：

```bash
python - <<'PY'
import torch
import numpy as np
from model import PolicyNet
from worker import Worker
from parameter import NODE_INPUT_DIM, EMBEDDING_DIM

ckpt_path = '/home/liuyi/projects/thermal_nav/ARiADNE-ROS-Planner/src/rl_planner/rl_planner/model/checkpoint.pth'
indices = [0, 1, 2, 3, 4]

checkpoint = torch.load(ckpt_path, map_location='cpu')
for idx in indices:
    torch.manual_seed(4777)
    np.random.seed(4777)
    model = PolicyNet(NODE_INPUT_DIM, EMBEDDING_DIM)
    model.load_state_dict(checkpoint['policy_model'])
    worker = Worker(0, model, idx, save_image=False)
    worker.run_episode()
    print(idx, worker.perf_metrics, 'steps', len(worker.episode_buffer[6]))
PY
```

本机输出：

```text
0 {'travel_dist': np.float64(296.8878817913662), 'explored_rate': np.float64(1.0), 'success_rate': True} steps 44
1 {'travel_dist': np.float64(221.03192163593565), 'explored_rate': np.float64(1.0), 'success_rate': True} steps 44
2 {'travel_dist': np.float64(212.14023140289245), 'explored_rate': np.float64(1.0), 'success_rate': True} steps 39
3 {'travel_dist': np.float64(337.6004641308594), 'explored_rate': np.float64(1.0), 'success_rate': True} steps 56
4 {'travel_dist': np.float64(255.4539399018772), 'explored_rate': np.float64(1.0), 'success_rate': True} steps 43
```

这 5 次快速测试的直接结论：

- `0,1,2,3,4` 这 5 个 episode 全部成功
- `explored_rate` 都达到了 `1.0`
- 步数分别是 `44 / 44 / 39 / 56 / 43`

## 7. 生成可视化轨迹 gif

目的：

- 用预训练模型生成一条可视化探索轨迹
- 方便直观看到 belief map、机器人轨迹、探索进度

命令：

```bash
python - <<'PY'
import torch
import numpy as np
from model import PolicyNet
from worker import Worker
from parameter import NODE_INPUT_DIM, EMBEDDING_DIM, gifs_path

ckpt_path = '/home/liuyi/projects/thermal_nav/ARiADNE-ROS-Planner/src/rl_planner/rl_planner/model/checkpoint.pth'
episode_index = 0

checkpoint = torch.load(ckpt_path, map_location='cpu')
torch.manual_seed(4777)
np.random.seed(4777)
model = PolicyNet(NODE_INPUT_DIM, EMBEDDING_DIM)
model.load_state_dict(checkpoint['policy_model'])
worker = Worker(0, model, episode_index, save_image=True)
worker.run_episode()
print(worker.perf_metrics)
print('steps', len(worker.episode_buffer[6]))
print('gifs_path', gifs_path)
PY
```

本机输出：

```text
gif complete

{'travel_dist': np.float64(296.8878817913662), 'explored_rate': np.float64(1.0), 'success_rate': True}
steps 44
gifs_path gifs/ariadne1_ground_truth_critic
```

本机生成文件：

- `gifs/ariadne1_ground_truth_critic/0_explored_rate_1.gif`
- `gifs/ariadne1_ground_truth_critic/0_44_samples.png`

当前绝对路径：

- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/gifs/ariadne1_ground_truth_critic/0_explored_rate_1.gif`
- `/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/gifs/ariadne1_ground_truth_critic/0_44_samples.png`

说明：

- `make_gif()` 会删除中间帧，只保留最后一帧 png 和最终 gif

## 8. 当前机器这次运行实际对应的地图文件名

这是一个重要注意事项。

`env.py` 里的地图选择逻辑是：

```python
map_list = os.listdir(map_dir)
map_index = episode_index % np.size(map_list)
```

也就是说，它没有对 `map_list` 排序。不同机器、不同文件系统顺序下，同一个 `episode_index` 不一定对应同一张图。

我在当前机器上用下面的命令记录了本次实际映射关系：

```bash
python - <<'PY'
import os
map_list = os.listdir('maps')
for idx in [0,1,2,3,4,77]:
    print(idx, map_list[idx])
PY
```

本机输出：

```text
0 img_260.png
1 img_2921.png
2 img_4977.png
3 705.png
4 img_3274.png
77 img_2572.png
```

所以本文档里的结果，在当前机器上更精确的表述应该是：

- `episode_index=77` 对应的是 `img_2572.png`
- `episode_index=0..4` 对应的是 `img_260.png / img_2921.png / img_4977.png / 705.png / img_3274.png`

## 9. 建议的后续动作

如果下一步还要继续聚焦当前训练仓库，而不是马上跳到 ROS 集成，我建议按这个顺序：

1. 先看刚生成的 gif，建立对“belief map + waypoint 选择”的直觉
2. 再挑几张固定地图做更系统一点的 2D 对比
3. 如果 2D 结论稳定，再回到 `ARiADNE-ROS-Planner` 看 ROS 侧输入输出
