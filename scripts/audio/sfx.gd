class_name Sfx
extends Node
## Synthesized sound effects plus the looping soundtrack ("2048 Quiet Tiles").

enum Kind { CLICK, SWIPE, MERGE, MILESTONE, LOSE }

const RATE := 44100
const VOICES := 8

const MUSIC_PATH := "res://assets/music/2048_Quiet_Tiles.mp3"
const MUSIC_RATE := 44100.0
## MP3 encoder delay in frames, measured against the master; make_game_music.py keeps it.
const MUSIC_DELAY_FRAMES := 1107
## The track is exactly this long and ends on a bar line, so the loop wraps here.
const MUSIC_LOOP_FRAMES := 5_880_000
## Linear music level at the top volume step, relative to full scale; sits under the effects.
const MUSIC_VOLUME := 0.8
## Bus gain in dB for volume steps 1..LEVEL_COUNT.
const LEVEL_DB := [-21.0, -16.0, -12.0, -9.0, -6.0, -3.0, 0.0]
const LEVEL_COUNT := 7
const SFX_BUS := &"SFX"
const MUSIC_BUS := &"Music"
const MUSIC_FADE_IN := 2.2
const MUSIC_FADE_OUT := 1.4

var sound_enabled := true
var music_enabled := false:
	set = set_music_enabled

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _music := AudioStreamPlayer.new()
var _music_tween: Tween
var _music_gain := 0.0:
	set(v):
		_music_gain = v
		_music.volume_db = linear_to_db(maxf(v * MUSIC_VOLUME, 0.00001))
var _music_bus_db := 0.0:
	set(v):
		_music_bus_db = v
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MUSIC_BUS), v)
var _level_tween: Tween


func _ready() -> void:
	_ensure_bus(SFX_BUS)
	_ensure_bus(MUSIC_BUS)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		_players.append(p)
	_music.bus = MUSIC_BUS
	_music.stream = make_music_stream()
	_music_gain = 0.0
	add_child(_music)
	_streams[Kind.CLICK] = _make_click()
	_streams[Kind.SWIPE] = _make_swipe()
	_streams[Kind.MERGE] = _make_pluck()
	_streams[Kind.MILESTONE] = _make_chime()
	_streams[Kind.LOSE] = _make_lose()


## The soundtrack looping sample-exactly: skips the encoder delay, wraps at the bar line.
static func make_music_stream() -> AudioStreamMP3:
	var s: AudioStreamMP3 = load(MUSIC_PATH)
	s.loop = true
	# Godot truncates seconds to frames; the half-frame keeps float error from landing one short.
	s.loop_offset = (MUSIC_DELAY_FRAMES + 0.5) / MUSIC_RATE
	# A one-beat "bar" as long as delay + music makes Godot wrap exactly at the loop end.
	s.beat_count = 1
	s.bpm = MUSIC_RATE * 60.0 / (MUSIC_DELAY_FRAMES + MUSIC_LOOP_FRAMES + 0.5)
	return s


## Plays [param kind]; [param pitch] scales playback speed, [param volume_db] offsets loudness.
func play(kind: Kind, pitch := 1.0, volume_db := 0.0) -> void:
	if not sound_enabled:
		return
	var p := _players[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	p.stream = _streams[kind]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


## Merge sound, rising a semitone per tile level and capped at one octave.
func play_merge(value: int) -> void:
	var step := Palette.tile_index(value)
	play(Kind.MERGE, pow(2.0, minf(step, 12) / 12.0), -2.0)


## Fades the soundtrack in or out. Off pauses it after the fade, so on resumes where it was.
func set_music_enabled(on: bool) -> void:
	music_enabled = on
	if not is_inside_tree():
		return
	if _music_tween:
		_music_tween.kill()
	if on:
		# A paused player reports playing == false, so unpause before deciding to start fresh.
		if _music.stream_paused:
			_music.stream_paused = false
		elif not _music.playing:
			_music.play(_music.stream.loop_offset)
		_music_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_music_tween.tween_property(self, "_music_gain", 1.0, MUSIC_FADE_IN * (1.0 - _music_gain))
	elif _music.playing and not _music.stream_paused:
		_music_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_music_tween.tween_property(self, "_music_gain", 0.0, MUSIC_FADE_OUT * _music_gain)
		_music_tween.tween_callback(func() -> void: _music.stream_paused = true)


## Current soundtrack fade level, 0 (silent) to 1 (full).
func music_level() -> float:
	return _music_gain


## Sets the effects volume step (1..LEVEL_COUNT); applies at once.
func set_sound_volume(step: int) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(SFX_BUS), level_db(step))


## Sets the music volume step (1..LEVEL_COUNT). With [param smooth], glides there to avoid a jump.
func set_music_volume(step: int, smooth := true) -> void:
	if _level_tween:
		_level_tween.kill()
	if not smooth or not is_inside_tree():
		_music_bus_db = level_db(step)
		return
	_level_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_level_tween.tween_property(self, "_music_bus_db", level_db(step), 0.2)


static func level_db(step: int) -> float:
	return LEVEL_DB[clampi(step, 1, LEVEL_COUNT) - 1]


static func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, &"Master")


func _make_click() -> AudioStreamWAV:
	var n := int(0.045 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 110.0)
		buf[i] = (sin(TAU * 1250.0 * t) * 0.6 + sin(TAU * 2500.0 * t) * 0.15) * env * 0.35
	return _to_wav(buf, RATE)


func _make_swipe() -> AudioStreamWAV:
	var n := int(0.11 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lp := 0.0
	for i in n:
		var t := float(i) / n
		var env := sin(PI * t) * (1.0 - t * 0.5)
		var cutoff := 0.05 + 0.25 * t
		lp += (rng.randf_range(-1.0, 1.0) - lp) * cutoff
		buf[i] = lp * env * 0.55
	return _to_wav(buf, RATE)


func _make_pluck() -> AudioStreamWAV:
	var n := int(0.24 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var f := 440.0
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t * 400.0) * exp(-t * 16.0)
		var bend := f * (1.0 + 0.04 * exp(-t * 40.0))
		var v := sin(TAU * bend * t) + 0.35 * sin(TAU * bend * 2.0 * t) * exp(-t * 30.0) + 0.1 * sin(TAU * bend * 3.0 * t)
		buf[i] = v * env * 0.42
	return _to_wav(buf, RATE)


func _make_chime() -> AudioStreamWAV:
	var notes := [523.25, 659.25, 783.99, 1046.5]
	var n := int(1.1 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for k in notes.size():
		var f: float = notes[k]
		var s0 := int(k * 0.075 * RATE)
		for i in range(s0, n):
			var t := float(i - s0) / RATE
			var env := minf(1.0, t * 300.0) * exp(-t * 4.5)
			buf[i] += (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.76 * t) * exp(-t * 8.0)) * env * 0.2
	return _to_wav(buf, RATE)


func _make_lose() -> AudioStreamWAV:
	var notes := [392.0, 329.63, 261.63]
	var n := int(1.3 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for k in notes.size():
		var f: float = notes[k]
		var s0 := int(k * 0.16 * RATE)
		for i in range(s0, n):
			var t := float(i - s0) / RATE
			var env := minf(1.0, t * 60.0) * exp(-t * 3.2)
			buf[i] += (sin(TAU * f * t) + 0.2 * sin(TAU * f * 2.0 * t)) * env * 0.22
	return _to_wav(buf, RATE)


static func _to_wav(buf: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var peak := 0.0
	for v in buf:
		peak = maxf(peak, absf(v))
	var gain := 0.9 / peak if peak > 0.9 else 1.0
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	return wav
