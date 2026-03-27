# ARiADNE vs TARE 最小对比记录表

当前阶段先只记 5 个字段，不把回原点时间混进主结论。

| 场景 | 方法 | `/exploration_finish` 是否变为 `true` | 从启动到探索完成耗时（s） | 探索完成前累计里程（m） |
|---|---|---|---:|---:|
| environment | ARiADNE |  |  |  |
| environment | TARE |  |  |  |

## 字段说明

- `场景`
  - 例如 `environment`、`office_building_1`、`office_building_2`
- `方法`
  - 固定写 `ARiADNE` 或 `TARE`
- ``/exploration_finish` 是否变为 `true``
  - `是` 表示完成探索
  - `否` 表示超时、卡住或你主动中断
- `从启动到探索完成耗时（s）`
  - 从你按下启动命令开始计时
  - 到 `/exploration_finish` 第一次变成 `true` 为止
- `探索完成前累计里程（m）`
  - 先用里程计或轨迹积分估算即可
  - 第一版实验只要求方法一致，不要求绝对值特别精确

## 当前阶段不要混进去的量

- 回原点耗时
- 回原点后的总里程
- 太多主观印象型描述

如果你想补主观观察，先单独记在表外：

- 是否有明显 waypoint 来回震荡
- 岔路/房间选择是否自然
- RViz 覆盖效果是否有明显漏扫
