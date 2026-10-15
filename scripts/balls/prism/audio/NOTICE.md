# 光棱球参考与音频素材

## 音源

音源来自 [Combined Arms 公开素材库](https://github.com/Inq8/CAmod/tree/ab9e477c3db818e91946d4cfdc86e71012966141/mods/ca/bits/audio)，获取日期为 2026-09-14，固定版本为 `ab9e477c3db818e91946d4cfdc86e71012966141`。

| 输出文件 | 时长 | 原始文件与处理范围 | 事件 |
| --- | --- | --- | --- |
| `prism_spawn.ogg` | 约 1.34 秒 | [`vprisea.aud`](https://raw.githubusercontent.com/Inq8/CAmod/ab9e477c3db818e91946d4cfdc86e71012966141/mods/ca/bits/audio/vprisea.aud)，完整短句 | 实际出场时播放光棱坦克报到语音 “Prism tank in order, sir.” |
| `prism_charge.ogg` | 0.32 秒 | [`bpripow.aud`](https://raw.githubusercontent.com/Inq8/CAmod/ab9e477c3db818e91946d4cfdc86e71012966141/mods/ca/bits/audio/bpripow.aud)，从 0.02 秒截取 | 蓄能 |
| `prism_fire.ogg` | 约 1.84 秒 | [`prisfire.aud`](https://raw.githubusercontent.com/Inq8/CAmod/ab9e477c3db818e91946d4cfdc86e71012966141/mods/ca/bits/audio/prisfire.aud)，完整放电短采样 | 发射 |
| `prism_hit.ogg` | 0.22 秒 | 同一 `prisfire.aud`，从 0.20 秒截取 | 一轮攻击至少命中一个目标 |

`vprisea` 是《红色警戒 2：尤里的复仇》的光棱坦克单位台词；`bpripow` 是红警光棱塔充能音。`prisfire` 是 Combined Arms 的光棱坦克武器采样，其 [武器配置](https://github.com/Inq8/CAmod/blob/ab9e477c3db818e91946d4cfdc86e71012966141/mods/ca/weapons/other.yaml) 将 `PrisLaser` 的发射声映射到该文件；未声称它与商业游戏中的 `vpriatta` 文件逐字节一致。

全部输出为 48 kHz、单声道、不循环的 Ogg Vorbis。没有使用 TTS、声纹克隆、机器重合成或变调。出场语音与开炮分别拥有独立事件；选球预览和擂台候补不触发语音，候补真正登场才播放。放电余光不重复触发声音。

## 权利边界

《红色警戒》原始录音及相关角色、商标归 Westwood Studios / Electronic Arts 及相应权利人所有。Combined Arms 仓库提供分发与取材出处；仓库的 GPL-3.0 说明不等于对其中第三方游戏录音授予无限制许可。本项目没有将这些音频重新许可为 MIT，也不表示版权方的认可或赞助。商业发布或分发应另行确认所需权利。

## 可复现处理

安装 Python 3 和带 `libvorbis` 的 FFmpeg 后，从项目根目录运行：

```sh
bash scripts/balls/prism/audio/render_samples.sh
```

可通过 `FFMPEG_BIN`、`PYTHON_BIN` 指定程序。脚本只覆盖上述四个 OGG 文件。原始 AUD 保存在 `source/`；`decode_sources.py` 检查文件头、所有块边界、声明解码长度与实际 PCM 样本量，裁去奇数末样本所需的单个 ADPCM 填充半字节。旧 FFmpeg AUD 解复用器在完整末块后报告的 EOF/EIO 提示，只有在上述完整性校验均通过时才被接受；其他异常直接失败。

PCM 转为浮点后执行 60 Hz 高通和 10.5 kHz 低通、3 ms 淡入及 25 ms 淡出、响度归一化、4 倍过采样限幅，最后编码为 Ogg Vorbis。目标响度为出场与发射 −18 LUFS、蓄能与命中 −22 LUFS，限幅器关闭自动增益。模块事件另外设置独立混音增益，不修改公共混音器。不同 FFmpeg/Vorbis 版本的编码字节可能不同。

原始素材 SHA-256：

```text
c1c7172480dff0bbdcd312862a994e9ba04742e7252ec3ccfaa608763d7ffa4b  vprisea.aud
e3b7b5591b0f3872ee60a40249483a62293a392f612e6aef8a56270ad4f7cf8b  prisfire.aud
cbc47d12f47700dacea2b0b271d96a6ad0b01f39e29e45dbc9f47b9688f9a77b  bpripow.aud
```

当前衍生文件 SHA-256：

```text
1bbe72cf966ae6aaa75f0320d93d745ccc9f2dc67668693a9dac7ffea29cd127  prism_spawn.ogg
759234e1ea1bb146371531c7e55bd177cdf0c857a58b3709f5f892fbebf6790b  prism_charge.ogg
3bfca3810374c5e39fa8961554e71ae71a517d5c3dcef630eebe701c7fcfa2af  prism_fire.ogg
ef49dc1ac2e625a517ac5cdcba3368e18646a41b1c9831f4b335586326a6ed8a  prism_hit.ogg
```

## 造型参考

造型参考 [Westwood 光棱坦克概念设定图](https://img.neoseeker.com/v_concept_art.php?caid=4114)中的浅色装甲、宽反射面板、分层发射孔与侧面铰接支架。游戏内由 `visual.gd` 自行绘制圆形装甲主体与前向光棱组件，不包含参考图位图，也不绘制外露履带。装甲位于球体轮廓内，发射器装饰不会扩大碰撞体。
