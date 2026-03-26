# ARiADNE / large-scale-DRL-exploration 文档索引

本目录现在区分两个并级工作区：

- `claude/`
- `codex/`

## 目录结构

- `README.md`
  - 当前总索引
- `claude/`
  - 保存 Claude 侧留下的文档
- `codex/`
  - 保存 Codex 侧编写的论文解读、代码理解、接入方案、调试手册、实验模板和 memory

## Claude 目录

- `claude/feasibility_analysis.md`
  - 从可行性角度评估是否值得把 `large-scale-DRL-exploration` / `ARiADNE` 引入当前项目
- `claude/project_context.md`
  - Claude 侧保留的项目背景、接口摘要和参数笔记
- `claude/urgent_tasks_for_other_ai.md`
  - 给其他代理/助手的短期任务提示

## Codex 目录

- `codex/project_code_walkthrough.md`
  - 从代码实现角度梳理当前 `large-scale-DRL-exploration` 仓库
- `codex/2d_validation_reproducibility_log.md`
  - 记录 2D smoke test、预训练 checkpoint 测试、5 图初测和 gif 生成命令
- `codex/paper_reading_deep_rl_large_scale_robot_exploration.md`
  - 论文《Deep Reinforcement Learning-Based Large-Scale Robot Exploration》的中文细读
- `codex/ariadne_three_stage_practical_guide.md`
  - 按“三步走”路线落地 ARiADNE 的中文教学文档
- `codex/ariadne_autonomy_stack_minimal_integration_plan.md`
  - 将 ARiADNE 接入 `autonomy_stack_mecanum_wheel_platform` 的最小改造方案
- `codex/ariadne_topic_tf_parameter_matrix.md`
  - 话题、TF、参数对照表
- `codex/ariadne_integration_debug_handbook.md`
  - 接入调试手册
- `codex/ariadne_experiment_record_template.md`
  - 实验记录模板
- `codex/system_scout_hesai_with_ariadne.launch.py`
  - 接入 `autonomy_stack` 的 launch 草案
- `codex/memory.md`
  - Codex 工作记忆和后续协作约定

## 推荐阅读顺序

如果你的目标是尽快开始做实验，建议按下面顺序读：

1. `codex/paper_reading_deep_rl_large_scale_robot_exploration.md`
2. `codex/ariadne_three_stage_practical_guide.md`
3. `codex/ariadne_autonomy_stack_minimal_integration_plan.md`
4. `codex/project_code_walkthrough.md`

如果你的目标是先判断是否值得继续投入，建议按下面顺序读：

1. `claude/feasibility_analysis.md`
2. `codex/paper_reading_deep_rl_large_scale_robot_exploration.md`
3. `codex/ariadne_three_stage_practical_guide.md`
