extends SceneTree

const SAMPLE_RATE := 44100
const DURATION_SECONDS := 1.28
const OUTPUT_PATH := "res://scripts/balls/train_conductor/audio/train_whistle.wav"

func _init() -> void:
	var frame_count := int(round(DURATION_SECONDS * SAMPLE_RATE))
	var pcm := PackedByteArray()
	pcm.resize(frame_count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 20260824
	var steam_pressure := 0.0
	for frame in range(frame_count):
		var time := float(frame) / SAMPLE_RATE
		var first_blast := _blast_envelope(time, 0.0, 0.46, 0.024, 0.11)
		var second_blast := _blast_envelope(time, 0.55, 1.24, 0.022, 0.18)
		var envelope := maxf(first_blast, second_blast * 0.94)
		# A fixed-pitch three-chime steam whistle. Deliberately avoid pitch glides,
		# vibrato and slow amplitude pulses: those modulations read as a human wail.
		var chord := (
			_horn_voice(time, 196.0) * 0.46
			+ _horn_voice(time, 246.94) * 0.31
			+ _horn_voice(time, 293.66) * 0.23
		)
		var raw_steam := random.randf_range(-1.0, 1.0)
		steam_pressure = lerpf(steam_pressure, raw_steam, 0.28)
		var valve_transient := (
			_exp_decay(time, 0.0, 0.045)
			+ _exp_decay(time, 0.55, 0.042)
		) * raw_steam * 0.13
		var steam_hiss := (raw_steam * 0.035 + steam_pressure * 0.025) * envelope
		var sample := clampf((chord * envelope + steam_hiss + valve_transient) * 0.64, -1.0, 1.0)
		pcm.encode_s16(frame * 2, int(round(sample * 32767.0)))
	_write_wav(pcm, frame_count)
	print("TRAIN_CONDUCTOR_WHISTLE_WRITTEN ", OUTPUT_PATH)
	quit(0)

func _write_wav(pcm: PackedByteArray, frame_count: int) -> void:
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Unable to open train whistle output: %s" % OUTPUT_PATH)
		quit(1)
		return
	file.big_endian = false
	file.store_buffer("RIFF".to_ascii_buffer())
	file.store_32(36 + pcm.size())
	file.store_buffer("WAVE".to_ascii_buffer())
	file.store_buffer("fmt ".to_ascii_buffer())
	file.store_32(16)
	file.store_16(1)
	file.store_16(1)
	file.store_32(SAMPLE_RATE)
	file.store_32(SAMPLE_RATE * 2)
	file.store_16(2)
	file.store_16(16)
	file.store_buffer("data".to_ascii_buffer())
	file.store_32(frame_count * 2)
	file.store_buffer(pcm)
	file.close()

func _smoothstep(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)

func _blast_envelope(
	time: float,
	start: float,
	finish: float,
	attack_duration: float,
	release_duration: float
) -> float:
	if time < start or time >= finish:
		return 0.0
	var attack := _smoothstep(clampf((time - start) / attack_duration, 0.0, 1.0))
	var release := _smoothstep(clampf((finish - time) / release_duration, 0.0, 1.0))
	return attack * release

func _horn_voice(time: float, frequency: float) -> float:
	return (
		sin(time * TAU * frequency)
		+ sin(time * TAU * frequency * 2.0) * 0.19
		+ sin(time * TAU * frequency * 3.0) * 0.075
	) / 1.265

func _exp_decay(time: float, start: float, decay_seconds: float) -> float:
	if time < start:
		return 0.0
	return exp(-(time - start) / decay_seconds)
