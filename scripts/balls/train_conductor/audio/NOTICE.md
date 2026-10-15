# 列车长汽笛音效

`train_whistle.wav` 是本项目使用 `generate_train_whistle.gd` 程序化合成的原创汽笛音效，不含第三方录音采样，可随项目代码按同一许可使用。它由固定音高的低音三管和弦、两次短鸣包络与蒸汽阀门噪声组成，刻意不使用升降调、颤音或慢速音量脉动，避免产生类似人声哀鸣的听感。

如需重新生成，在 Godot 项目根目录运行：

```bash
godot --headless --path . --script res://scripts/balls/train_conductor/audio/generate_train_whistle.gd
```
