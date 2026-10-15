# 五条悟球语音素材声明

本目录的四条招式语音使用《咒术回战》五条悟日语动画原声短采样，不是 TTS、AI 克隆或机器合成语音。为去除源片段自带的背景音乐，语音经过 Demucs 4.0.1 `htdemucs_ft` 四模型的 `vocals` 双轨分离，再做 70 Hz 高通、15 kHz 低通、单声道 48 kHz 转换和 `-17 LUFS` 目标响度归一化及峰值限幅；没有升降调、变声或声纹替换。

| 派生文件 | 内容 | 来源页面 | 公开源文件 | 源文件 SHA-256 | 派生文件 SHA-256 |
| --- | --- | --- | --- | --- | --- |
| `gojo_blue.ogg` | 「苍」纯人声短报招 | [Gojo Soundboard / Gojo Lapse Blue](https://soundboardmax.com/gojo-soundboard/) | [下载 MP3](https://cdn.soundboardmax.com/2025/09/Gojo-Lapse-Blue.mp3) | `1171c8be4f22c54b7182ece1f3dbbea613c31936f724506b8b66b87e33b2b2fe` | `7196f25fe0fd5f76a5f6d64745f76d8e6fd7d4d69038c5b06bf640d0e3baed71` |
| `gojo_red.ogg` | 「赫」纯人声短报招 | [Gojo Soundboard / Gojo Reversal Red](https://soundboardmax.com/gojo-soundboard/) | [下载 MP3](https://cdn.soundboardmax.com/2025/09/Gojo-Reversal-Red.mp3) | `05a25b5d8479a134b0dbc1bf694ed6228b7b749603b6ccd4b347b42186e8e1bc` | `9e39c15553696440ba6c703a149c3b3091688e8816699d8bdff3360482e7ade7` |
| `gojo_purple.ogg` | 「茈」纯人声短报招 | [Gojo Soundboard / Hollow Purple](https://soundboardmax.com/gojo-soundboard/) | [下载 MP3](https://cdn.soundboardmax.com/2025/09/Hollow-Purple.mp3) | `8b38d71dfcd2cb99328bcefe35484e8bacfaa99d395db6eb234b91b6a90d48c3` | `df79181c7a7f1df6de6a7e0968fcfc74becde72f171eca7e3af1a90b303627c0` |
| `gojo_domain.ogg` | 「无量空处」纯人声短报招 | [Shibuya Gojo Domain](https://www.myinstants.com/en/instant/shibuya-gojo-domain-40826/) | [下载 MP3](https://www.myinstants.com/media/sounds/shibuya-gojo-domain.mp3) | `692a8550dc8ce11dd12d1816bf09d4e20b15f194c4ce92fcd051505b3daa39c2` | `4748b4af68083634808523b28f29c3c28bb08c8efc4af0202ca890955a0ae1d8` |

## 一秒内短报招

每段成品含首尾空白在内均不超过 1 秒。苍、赫、茈只保留招式名，无量空处去掉前面的“领域展开”。不保留长咏唱或句间等待。

本目录 `render_short_voice.sh` 接受语音 ID、净化源文件和输出路径，校验输入 SHA-256 后按下表裁切。使用 FFmpeg Rubber Band，`pitch=1`、`formant=preserved`、`transients=mixed`、`pitchq=quality` 做保音高加速。苍使用完整的 12.312 秒人声分轨；其他三段使用加速前的净化 OGG，避免重复拉伸已压缩的短版。

| 文件 | 净化输入 SHA-256 | 保留区间（秒） | 速度 | 成品长度（秒） |
| --- | --- | --- | --- | --- |
| `gojo_blue.ogg` | `873cdb55fd8f6f5ed1a4bf83c714aa312e9cc921ce072d109879d01514e1aae1` | 9.97–11.49 | 1.65× | 0.921208 |
| `gojo_red.ogg` | `708045d77449dbc7d4433d63c34b08df8fe93bf43cd8d231dbd584bccd61d6fc` | 1.66–3.42 | 1.90× | 0.926313 |
| `gojo_purple.ogg` | `43adc9eb85830ddfa1bdf80ee7862f680acf55d9da16be5c7296d0888aee6e43` | 1.29–2.34 | 1.15× | 0.913042 |
| `gojo_domain.ogg` | `d93ac1685ff55aa3118b3839b8046282b621044de68e8004b85f4eb308d140f2` | 3.03–4.47 | 1.55× | 0.929042 |

头尾分别淡化 3 ms、15 ms；经过 70 Hz 高通、15 kHz 低通、`loudnorm=I=-17:LRA=7:TP=-1.5`，再做 192 kHz 过采样限幅（上限 −2 dB、5 ms attack、50 ms release、关闭自动增益并补偿延迟），最后转为 48 kHz 单声道、Vorbis `q=6`。成品响度/真峰值分别为：苍 −18.3 LUFS/−2.8 dBTP、赫 −17.7/−2.1、茈 −17.8/−2.0、无量空处 −17.1/−5.9。模块事件增益、播放音调、技能触发时机均不变。

生成脚本在编码后检查总时长，超过 1 秒即报错。`tests/test_gojo_voice_assets.py` 解码四个生产文件，检查 1 秒上限、采样格式、中间空白与首尾静音；`tests/test_gojo_ball.gd` 检查 Godot 实际导入的时长、单次播放和事件增益。

## 来源与许可

语音素材于 2026-08-30 获取，并于 2026-09-02 从上表公开源文件地址重新下载、逐项核对 SHA-256，使用同一 `htdemucs_ft` 四模型流程复核人声分轨。五条悟球不再注册或播放独立背景音乐。原始角色、表演和录音版权归各自权利方所有；这些音频不纳入项目 MIT 许可，也不表示版权方对本项目的认可。公开发布前应由发布者自行确认目标平台和地区的授权要求。
