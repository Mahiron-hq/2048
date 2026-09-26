class_name Sfx
extends Node
## Procedurally synthesized sound effects and an ambient music loop. No audio files ship.

enum Kind { CLICK, SWIPE, MERGE, MILESTONE, LOSE }

const RATE := 44100
const MUSIC_RATE := 22050
const VOICES := 8
const MUSIC_DB := -13.0

var sound_enabled := true
var music_enabled := false:
	set = set_music_enabled

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _music := AudioStreamPlayer.new()
var _music_task := -1
var _music_stream: AudioStreamWAV
var _music_tween: Tween


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music.volume_db = -80.0
	add_child(_music)
	_streams[Kind.CLICK] = _make_click()
	_streams[Kind.SWIPE] = _make_swipe()
	_streams[Kind.MERGE] = _make_pluck()
	_streams[Kind.MILESTONE] = _make_chime()
	_streams[Kind.LOSE] = _make_lose()


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


func set_music_enabled(on: bool) -> void:
	music_enabled = on
	if not is_inside_tree():
		return
	if on:
		if _music_stream:
			_start_music()
		elif _music_task < 0:
			_music_task = WorkerThreadPool.add_task(_build_music, false, "music synth")
			set_process(true)
	else:
		_fade_music(-80.0, 0.6, true)


func _process(_delta: float) -> void:
	if _music_task < 0 or not WorkerThreadPool.is_task_completed(_music_task):
		if _music_task < 0:
			set_process(false)
		return
	WorkerThreadPool.wait_for_task_completion(_music_task)
	_music_task = -1
	set_process(false)
	if music_enabled:
		_start_music()


func _exit_tree() -> void:
	if _music_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1


func _start_music() -> void:
	if _music.stream != _music_stream:
		_music.stream = _music_stream
	if not _music.playing:
		_music.volume_db = -40.0
		_music.play()
	_fade_music(MUSIC_DB, 1.6, false)


func _fade_music(db: float, time: float, stop_after: bool) -> void:
	if _music_tween:
		_music_tween.kill()
	if not _music.playing:
		return
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", db, time)
	if stop_after:
		_music_tween.tween_callback(_music.stop)


## Worker thread: renders the loop. Touches no scene nodes.
func _build_music() -> void:
	_music_stream = build_music_stream()


## Renders the ambient loop: four soft chords with an arpeggio, phase-continuous across the seam.
static func build_music_stream() -> AudioStreamWAV:
	var chords := [
		[261.63, 329.63, 392.0, 493.88],
		[220.0, 261.63, 329.63, 392.0],
		[174.61, 220.0, 261.63, 329.63],
		[196.0, 246.94, 293.66, 392.0],
	]
	var seg := 4.0
	var total := int(seg * chords.size() * MUSIC_RATE)
	var buf := PackedFloat32Array()
	buf.resize(total)
	var fade := 1.2
	for c in chords.size():
		var start := c * seg
		var from := int((start - fade) * MUSIC_RATE)
		var to := int((start + seg + fade) * MUSIC_RATE)
		var span := float(to - from)
		for note in chords[c]:
			var f: float = note * 0.5
			for i in range(from, to):
				var w := sin(PI * (i - from) / span)
				var t := float(i) / MUSIC_RATE
				var v := sin(TAU * f * t) + 0.5 * sin(TAU * f * 1.003 * t) + 0.12 * sin(TAU * f * 2.0 * t)
				var k := posmod(i, total)
				buf[k] += v * w * w * 0.09
		var arp: Array = chords[c]
		for n in 8:
			var f2: float = arp[[0, 1, 2, 3, 2, 1, 2, 3][n]] * 2.0
			var s0 := int((start + n * 0.5) * MUSIC_RATE)
			var length := int(0.9 * MUSIC_RATE)
			for i in length:
				var t := float(i) / MUSIC_RATE
				var env := minf(1.0, t * 200.0) * exp(-t * 5.0)
				var v := sin(TAU * f2 * t) + 0.25 * sin(TAU * f2 * 2.0 * t)
				buf[posmod(s0 + i, total)] += v * env * 0.07
	# The mixer reads loop_end inclusively and the buffer has no padding, so a loop_end equal to the
	# frame count reads past the allocation (a SIGSEGV on Android). Repeating frame 0 at the end keeps
	# the read in bounds and the seam sample-exact.
	buf.append(buf[0])
	var wav := _to_wav(buf, MUSIC_RATE)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = total
	return wav


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
