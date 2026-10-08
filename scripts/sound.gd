class_name InkSound
extends Node

var game
var notes: Array = []
var spatial_notes: Array = []
var cache: Dictionary = {}
var manifest: Dictionary = {}
var music_players: Array = []
var music_index = 0
var current_track = ""
var fade = 1.0
var loops: Dictionary = {}
var last_play: Dictionary = {}
var clock = 0.0
var enabled = true

const ALIASES={"ui":"ui_click","shot":"shoot_shooter","boom":"bomb_explode","splat":"splatted_self","jump":"super_jump","special":"special_ready","throw":"bomb_throw","brolly_shoot":"brolly_blast","blade_tap":"blade_swish","shoot_bucket":"shoot_slosher","shoot_twins":"shoot_dualies","shoot_spinner":"shoot_splatling"}

func setup(owner_game):
	game=owner_game
	if FileAccess.file_exists("res://assets/audio/manifest.json"):
		manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/manifest.json"))
	for i in 32:
		var player=AudioStreamPlayer.new();add_child(player);notes.append(player)
	for i in 24:
		var player=AudioStreamPlayer3D.new();player.max_distance=55;player.unit_size=8;player.max_polyphony=1
		add_child(player);spatial_notes.append(player)
	for i in 2:
		var player=AudioStreamPlayer.new();add_child(player);music_players.append(player)

func _stream(key: String) -> AudioStream:
	if not cache.has(key):
		var path="res://assets/audio/"+key+".wav"
		if not ResourceLoader.exists(path):return null
		cache[key]=load(path)
	return cache[key]

func effect(kind: String,volume: float=0.4,pos: Vector3=Vector3.INF,pitch: float=1.0):
	if not enabled or game.headless_test:return
	kind=ALIASES.get(kind,kind)
	if clock-float(last_play.get(kind,-100))<0.035:return
	var stream=_stream("sfx_"+kind)
	if not stream:return
	last_play[kind]=clock
	var pool=notes if pos==Vector3.INF else spatial_notes
	var player=pool[0]
	for voice in pool:
		if not voice.playing:player=voice;break
	player.stream=stream
	player.volume_db=linear_to_db(maxf(0.0001,volume*pow(float(game.settings.master)*float(game.settings.sfx),1.5)))
	player.pitch_scale=pitch
	if player is AudioStreamPlayer3D:player.global_position=pos
	player.play()

func set_loop(key: String,kind: String,volume: float,pitch: float=1):
	if game.headless_test:return
	if volume<=0:
		if loops.has(key):loops[key].stop();loops[key].queue_free();loops.erase(key)
		return
	if not loops.has(key):
		var original=_stream("sfx_"+kind)
		if not original:return
		var stream=original.duplicate()
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin=int(0.12*stream.mix_rate)
		stream.loop_end=int(maxf(0.15,stream.get_length()-0.15)*stream.mix_rate)
		var voice=AudioStreamPlayer.new();voice.stream=stream;add_child(voice);voice.play();loops[key]=voice
	var voice=loops[key]
	voice.pitch_scale=pitch
	voice.volume_db=linear_to_db(maxf(0.0001,volume*pow(float(game.settings.master)*float(game.settings.sfx),1.5)))

func play_music(id: String):
	if id==current_track:return
	var source=_stream("music_"+id)
	if not source:return
	current_track=id
	music_index=1-music_index
	var stream=source.duplicate()
	var data: Dictionary=manifest.get("music",{}).get(id,{})
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin=int(float(data.get("loopFrom",0))*stream.mix_rate)
	stream.loop_end=int(float(data.get("loopEnd",stream.get_length()))*stream.mix_rate)
	music_players[music_index].stream=stream
	music_players[music_index].volume_db=-70
	music_players[music_index].play()
	fade=0

func _process(dt: float):
	if not game or not enabled or game.headless_test:return
	clock+=dt
	var desired="title" if game.hud.screen=="main" else "menu"
	if game.state=="playing":
		desired="battle_final" if game.time_left<=60 else str(game.settings.get("battleMusic","battle"))
		if game.mode=="boss" and game.boss:desired="boss" if game.boss.phase==1 else "boss_"+str(game.boss.phase)
	elif game.state=="results":desired="results_win" if game.result.get("winner",1)==game.local_actor.team else "results_lose"
	play_music(desired)
	fade=minf(1,fade+dt/0.8)
	var level=pow(float(game.settings.master)*float(game.settings.music),1.5)
	for i in 2:
		music_players[i].volume_db=linear_to_db(maxf(0.0001,level*(fade if i==music_index else 1-fade)))
		if i!=music_index and fade>=1:music_players[i].stop()
	var a=game.local_actor
	if a and game.state=="playing" and a.alive():
		set_loop("swim","swim",0.35 if a.submerged and a.velocity.length()>0.5 else 0,clampf(a.velocity.length()/10,0.7,1.5))
		set_loop("charge","charger_charge",0.22 if a.charge>0 else 0,1+a.charge*1.5)
	else:
		for key in loops.keys():set_loop(key,"",0)

func stop_all():
	enabled=false
	for player in notes+spatial_notes+music_players+loops.values():
		if is_instance_valid(player):player.stop();player.stream=null
	cache.clear()

func _exit_tree():
	stop_all()
