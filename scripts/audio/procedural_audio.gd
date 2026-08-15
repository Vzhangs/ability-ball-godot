class_name ProceduralBattleAudio
extends Node

const SAMPLE_RATE := 44100.0
const MAX_VOICES := 14

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _voices: Array[Dictionary] = []
var _noise := RandomNumberGenerator.new()

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_noise.seed = 20260815
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = SAMPLE_RATE
	generator.buffer_length = 0.25
	_player = AudioStreamPlayer.new()
	_player.stream = generator
	_player.volume_db = -7.0
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	set_process(true)

func _exit_tree() -> void:
	shutdown()

func shutdown() -> void:
	set_process(false)
	_voices.clear()
	_playback = null
	if _player != null:
		_player.stop()
		_player.stream = null

func play_event(kind: String, strength: float = 1.0) -> void:
	var voice := {
		"age": 0.0,
		"duration": 0.13,
		"frequency": 180.0,
		"frequency_end": 72.0,
		"phase": 0.0,
		"strength": clampf(strength, 0.0, 1.0),
		"wave": "sine",
		"noise": 0.0,
	}
	match kind:
		"impact":
			voice["duration"] = 0.16
			voice["frequency"] = 145.0
			voice["frequency_end"] = 58.0
			voice["noise"] = 0.2
		"judgment":
			voice["duration"] = 0.28
			voice["frequency"] = 880.0
			voice["frequency_end"] = 420.0
			voice["wave"] = "square"
			voice["noise"] = 0.04
		"track":
			voice["duration"] = 0.09
			voice["frequency"] = 96.0
			voice["frequency_end"] = 70.0
			voice["wave"] = "triangle"
			voice["noise"] = 0.13
		"blood":
			voice["duration"] = 0.34
			voice["frequency"] = 310.0
			voice["frequency_end"] = 82.0
			voice["wave"] = "saw"
			voice["noise"] = 0.09
		_:
			return
	_voices.append(voice)
	while _voices.size() > MAX_VOICES:
		_voices.pop_front()

func _process(_delta: float) -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	for _frame in range(frames):
		var mixed := 0.0
		for index in range(_voices.size() - 1, -1, -1):
			var voice := _voices[index]
			var age: float = voice["age"]
			var duration: float = voice["duration"]
			if age >= duration:
				_voices.remove_at(index)
				continue
			var progress := age / duration
			var frequency := lerpf(float(voice["frequency"]), float(voice["frequency_end"]), progress)
			var phase: float = voice["phase"]
			var wave := _wave_value(String(voice["wave"]), phase)
			var envelope := sin(progress * PI) * exp(-progress * 2.25)
			var noise_amount: float = voice["noise"]
			wave = lerpf(wave, _noise.randf_range(-1.0, 1.0), noise_amount)
			mixed += wave * envelope * float(voice["strength"]) * 0.48
			voice["phase"] = fmod(phase + TAU * frequency / SAMPLE_RATE, TAU)
			voice["age"] = age + 1.0 / SAMPLE_RATE
			_voices[index] = voice
		mixed = tanh(mixed)
		_playback.push_frame(Vector2(mixed, mixed))

func _wave_value(kind: String, phase: float) -> float:
	match kind:
		"square":
			return 1.0 if sin(phase) >= 0.0 else -1.0
		"triangle":
			return asin(sin(phase)) * 2.0 / PI
		"saw":
			return 2.0 * (phase / TAU) - 1.0
		_:
			return sin(phase)
