class_name Sfx
extends RefCounted

const UI := "res://Assets/kenney_ui-pack/Sounds/"
const MAP := {
	"pick": [UI + "tap-a.ogg", -4.0, 1.0],
	"put": [UI + "tap-b.ogg", -4.0, 0.9],
	"click": [UI + "click-a.ogg", -6.0, 1.0],
	"clean": [UI + "switch-a.ogg", -3.0, 1.2],
	"cook": [UI + "switch-b.ogg", -6.0, 1.0],
}

# Effects with no sample file are synthesised: [kind, seconds, start Hz, end Hz, volume dB]
const SYNTH := {
	"chop": ["noise", 0.07, 900.0, 300.0, -8.0],
	"wash": ["noise", 0.25, 2500.0, 1500.0, -16.0],
	"tarik": ["tone", 0.22, 300.0, 700.0, -12.0],
	"burn": ["noise", 0.5, 400.0, 100.0, -6.0],
	"dash": ["noise", 0.18, 1800.0, 500.0, -14.0],
	"serve": ["tone", 0.3, 660.0, 990.0, -8.0],
	"jump": ["tone", 0.2, 250.0, 600.0, -12.0],
	"fire": ["noise", 0.4, 1200.0, 300.0, -10.0],
	"splash": ["noise", 0.5, 3000.0, 800.0, -8.0],
	"stinger": ["chord", 0.7, 523.0, 0.0, -9.0],
	"crit": ["chord", 0.9, 392.0, 0.0, -9.0],
	"alarm": ["tone", 0.35, 880.0, 660.0, -12.0],
	"meow": ["tone", 0.45, 700.0, 420.0, -12.0],
}

# Voice-like shouts built from vowel formants: [vowel, seconds, pitch Hz]. Subtitles carry the meaning.
const VOWELS := {"a": [800.0, 1200.0], "i": [300.0, 2300.0], "u": [350.0, 900.0], "e": [500.0, 1800.0], "o": [500.0, 1000.0]}
const VOICE := {
	"siap": [["i", 0.09, 300.0], ["a", 0.16, 260.0]],
	"panas": [["a", 0.12, 240.0], ["a", 0.1, 280.0], ["a", 0.14, 220.0]],
	"aiyo": [["a", 0.1, 300.0], ["i", 0.1, 340.0], ["o", 0.2, 260.0]],
	"mantap": [["a", 0.1, 250.0], ["a", 0.1, 300.0], ["a", 0.16, 340.0]],
}

static var _loops := {}

static var _pool: Array[AudioStreamPlayer] = []
static var _streams := {}


static func _synth(name: String) -> AudioStreamWAV:
	var d: Array = SYNTH[name]
	var rate := 22050
	var n := int(float(d[1]) * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = name.hash()
	var lp := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(float(d[2]), float(d[3]), t)
		var env := minf(t * 30.0, 1.0) * pow(1.0 - t, 2.0)
		var v := 0.0
		if d[0] == "chord":
			for r in [1.0, 1.25, 1.5, 2.0]:
				phase = TAU * float(d[2]) * r * float(i) / rate
				v += sin(phase) * 0.22
		elif d[0] == "tone":
			phase += TAU * f / rate
			v = sin(phase) * 0.7 + sin(phase * 2.0) * 0.2
		else:
			var white := rng.randf_range(-1.0, 1.0)
			var a := clampf(f / 8000.0, 0.02, 0.95)
			lp += (white - lp) * a
			v = lp * 1.6
		data.encode_s16(i * 2, int(clampf(v * env, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w


static func _voice(name: String) -> AudioStreamWAV:
	var rate := 22050
	var parts: Array = VOICE[name]
	var data := PackedByteArray()
	var phase := 0.0
	for pt in parts:
		var n := int(float(pt[1]) * rate)
		var f1: float = VOWELS[pt[0]][0]
		var f2: float = VOWELS[pt[0]][1]
		var f0: float = pt[2]
		for i in n:
			var t := float(i) / n
			var env := minf(t * 12.0, 1.0) * minf((1.0 - t) * 6.0, 1.0)
			phase += TAU * f0 / rate
			var v := 0.0
			for h in range(1, 24):
				var fh := f0 * h
				var g := 1.0 / (1.0 + pow((fh - f1) / 220.0, 2.0)) + 0.6 / (1.0 + pow((fh - f2) / 300.0, 2.0))
				v += sin(phase * h) * g / h
			var b := PackedByteArray()
			b.resize(2)
			b.encode_s16(0, int(clampf(v * env * 0.55, -1.0, 1.0) * 26000.0))
			data.append_array(b)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w


static func shout(name: String) -> void:
	if not VOICE.has(name):
		return
	if not _streams.has("voice_" + name):
		_streams["voice_" + name] = _voice(name)
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var p := AudioStreamPlayer.new()
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.stream = _streams["voice_" + name]
	p.volume_db = -6.0
	p.finished.connect(p.queue_free)
	root.add_child.call_deferred(p)
	p.ready.connect(p.play, CONNECT_ONE_SHOT)


# A looping positional player (sizzle, boil, hum). Caller adds it to a 3D node.
static func loop3d(kind: String) -> AudioStreamPlayer3D:
	if not _loops.has(kind):
		var rate := 22050
		var n := rate
		var data := PackedByteArray()
		data.resize(n * 2)
		var rng := RandomNumberGenerator.new()
		rng.seed = kind.hash()
		var lp := 0.0
		for i in n:
			var white := rng.randf_range(-1.0, 1.0)
			var v := 0.0
			if kind == "sizzle":
				lp += (white - lp) * 0.7
				v = lp * (0.35 + 0.65 * maxf(rng.randf() - 0.55, 0.0) * 2.0) * 0.5
			elif kind == "boil":
				lp += (white - lp) * 0.08
				v = lp * (0.5 + 0.5 * sin(TAU * 7.0 * float(i) / rate)) * 1.4
			else:
				v = sin(TAU * 120.0 * float(i) / rate) * 0.3
			data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 24000.0))
		var w := AudioStreamWAV.new()
		w.format = AudioStreamWAV.FORMAT_16_BITS
		w.mix_rate = rate
		w.data = data
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = n
		_loops[kind] = w
	var p := AudioStreamPlayer3D.new()
	p.stream = _loops[kind]
	p.unit_size = 2.5
	p.max_distance = 9.0
	p.volume_db = -12.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	return p


static func play(name: String) -> void:
	var d: Array
	var path: String
	if SYNTH.has(name):
		d = [name, SYNTH[name][4], 1.0]
		path = name
		if not _streams.has(path):
			_streams[path] = _synth(name)
	elif MAP.has(name):
		d = MAP[name]
		path = d[0]
		if not _streams.has(path):
			_streams[path] = load(path) if ResourceLoader.exists(path) else null
	else:
		return
	if _streams[path] == null:
		return
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var p: AudioStreamPlayer = null
	for q in _pool:
		if is_instance_valid(q) and not q.playing:
			p = q
			break
	if p == null:
		p = AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		root.add_child.call_deferred(p)
		_pool.append(p)
	p.stream = _streams[path]
	p.volume_db = float(d[1])
	p.pitch_scale = float(d[2]) * randf_range(0.94, 1.06)
	if p.is_inside_tree():
		p.play()
	elif not p.ready.is_connected(p.play):
		p.ready.connect(p.play, CONNECT_ONE_SHOT)


static var _music: AudioStreamPlayer
static var _drive: AudioStreamPlayer


# 0 = calm, 1 = last seconds. Speeds the tune up slightly and fades in a fast pulse layer.
static func urgency(x: float) -> void:
	if is_instance_valid(_music):
		_music.pitch_scale = lerpf(1.0, 1.14, x)
	if is_instance_valid(_drive):
		_drive.volume_db = lerpf(-60.0, -24.0, x)


# Looping pentatonic marimba-style tune, synthesised so no audio file is needed.
static func music() -> void:
	Prefs.load_prefs()
	Prefs.apply_audio()
	if is_instance_valid(_music):
		return
	var rate := 22050
	var scale := [0, 2, 4, 7, 9, 12, 9, 7, 4, 7, 9, 7, 4, 2, 0, -3]
	var beat := 0.25
	var n := int(scale.size() * beat * rate)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in scale.size():
		var f := 261.63 * pow(2.0, float(scale[i]) / 12.0)
		var start := int(i * beat * rate)
		for j in int(beat * 1.6 * rate):
			if start + j >= n:
				break
			var t := float(j) / rate
			var env := exp(-t * 7.0)
			buf[start + j] += (sin(TAU * f * t) + 0.35 * sin(TAU * f * 2.0 * t)) * env * 0.5
		if i % 4 == 0:
			var bf := f * 0.5
			for j in int(beat * 3.0 * rate):
				if start + j >= n:
					break
				var t2 := float(j) / rate
				buf[start + j] += sin(TAU * bf * t2) * exp(-t2 * 2.5) * 0.4
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 20000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = n
	var dn := int(2.0 * rate)
	var dbuf := PackedByteArray()
	dbuf.resize(dn * 2)
	for i in dn:
		var t3 := fmod(float(i) / rate, 0.125)
		var step := int(float(i) / rate / 0.125)
		var f3 := 523.25 * (1.0 if step % 4 != 3 else 1.5)
		var e3 := exp(-t3 * 30.0)
		dbuf.encode_s16(i * 2, int(sin(TAU * f3 * t3) * e3 * 12000.0))
	var dw := AudioStreamWAV.new()
	dw.format = AudioStreamWAV.FORMAT_16_BITS
	dw.mix_rate = rate
	dw.data = dbuf
	dw.loop_mode = AudioStreamWAV.LOOP_FORWARD
	dw.loop_end = dn
	_drive = AudioStreamPlayer.new()
	_drive.stream = dw
	_drive.volume_db = -60.0
	_drive.bus = "Music"
	_drive.process_mode = Node.PROCESS_MODE_ALWAYS
	(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_drive)
	_drive.ready.connect(_drive.play, CONNECT_ONE_SHOT)
	_music = AudioStreamPlayer.new()
	_music.stream = w
	_music.volume_db = -20.0
	_music.bus = "Music"
	_music.process_mode = Node.PROCESS_MODE_ALWAYS
	(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_music)
	_music.ready.connect(_music.play, CONNECT_ONE_SHOT)
