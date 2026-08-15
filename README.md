# Ability Ball Lab

一个用 Godot 4 编写的原创程序化“能力球”战斗项目。默认剧本为“吸血鬼 VS 六王球”：固定种子下，吸血鬼以吸血、冲刺和血爆作战；六王球逐步解锁锚点牵引、棋盘审判、旋转轨道和环绕列车，最终进入高密度第三阶段。球库模式另有 10 个可任选配对的球。

所有战斗逻辑、矢量画面和音效都由项目代码生成，不依赖外部美术或音频素材。

## 运行

需要 Godot 4.7 或兼容的 Godot 4.x 版本：

```bash
godot --path .
```

操作：

- `空格`：暂停/继续
- `R`：使用相同种子重开
- `N`：使用随机种子重开
- `1`、`2`、`4`：切换演算速度
- 也可以在界面底部输入任意非零整数种子
- 使用左右下拉框选择球，再点击“开始对战”

默认种子 `20260815` 会在约 106 秒结束，六王球以约 110 点生命值获胜。

## 球库

| ID | 球 | 能力 |
| --- | --- | --- |
| `vampire` | 吸血鬼 | 吸血碰撞、血爆回复 |
| `six_king` | 六王球 | 六向锚点、轨道审判 |
| `splitter` | 分裂球 | 受击分裂、分身撞击 |
| `black_hole` | 黑洞球 | 引力牵引、事件视界 |
| `heaven` | 天堂球 | 短暂无敌、神圣冲刺 |
| `sonic` | 音速球 | 持续加速、音爆冲撞 |
| `replicator` | 复制器 | 复制镜像、齐射弹幕 |
| `hammer` | 锤子球 | 旋转长锤、范围重击 |
| `laser` | 激光球 | 锁定蓄力、穿透光束 |
| `flame` | 火焰球 | 灼烧轨迹、烈焰爆发 |

默认的“吸血鬼 VS 六王球”使用完整 Boss 战；其他选择进入 52 秒上限的通用球库战。近期 B 站投稿与第二批候选见[球种调研](docs/research/2026-08-15-bilibili-ball-roster.md)。

## 新增一种球

在 `scripts/balls/<id>/` 新建三个文件即可，注册表会自动发现，不需要修改模拟器、视图、主界面或出片脚本：

- `module.gd`：名称、颜色、生命、速度、伤害、冷却、音效类型和排序；
- `ability.gd`：继承 `BallAbility`，按需实现移动、逐帧、主动能力、碰撞和伤害后钩子；
- `visual.gd`：继承 `BallVisual`，实现球体、附属物和尾迹参数。

能力通过 `BallBattleContext` 请求伤害、治疗、随机数、投射物和特效，不直接依赖模拟器内部数据。运行球库测试后，新球会自动加入注册完整性检查和全组合对战。

## 一键生成竖屏视频

macOS / Linux：

```bash
./tools/render_video.sh 20260815
```

脚本会用 Godot 的离线 Movie Maker 录制 720×1280、30 FPS 母版，裁去游戏操作区，再用 FFmpeg 转为接近参考视频构图的 1080×1440、H.264/AAC MP4。成片写入 `builds/ability-ball-seed-20260815.mp4`。更换命令末尾的整数即可批量生成不同战局。

生成任意球库组合时，再传入左右球 ID：

```bash
./tools/render_video.sh 20260816 splitter black_hole
./tools/render_video.sh 20260817 heaven sonic
./tools/render_video.sh 20260818 hammer replicator
```

输出文件名会包含球种与种子，例如 `builds/ability-ball-splitter-vs-black_hole-seed-20260816.mp4`。

如果 Godot 或 FFmpeg 不在 `PATH` 中，可以指定可执行文件：

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
FFMPEG_BIN=/opt/homebrew/bin/ffmpeg \
./tools/render_video.sh 20260815
```

## 验证

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_battle.gd
godot --headless --path . --script res://tests/test_roster_battle.gd
godot --headless --path . --script res://tests/test_roster_view.gd
godot --headless --path . --quit-after 120
```

测试会检查角色边界、阶段推进、技能触发、吸血回复、伤害统计、默认结局、同种子确定性与不同种子差异；球库测试会按当前球数自动跑完 `N×(N−1)/2` 种异种组合，并逐个加载所有球的真实绘制策略。

## 主要目录

- `scripts/simulation/`：固定步长、带种子的纯战斗模拟
- `scripts/balls/`：每种球的配置、能力和视觉插件，以及稳定契约
- `scripts/ui/`：通用竞技场、HUD 和战场特效
- `scripts/audio/`：实时合成的程序音效
- `tests/`：无需图形界面的回归测试
- `tools/`：竖屏视频生成脚本
- `docs/plans/`：玩法与实现设计

项目以 MIT License 发布。
