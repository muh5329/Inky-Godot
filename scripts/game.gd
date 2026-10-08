extends Node3D

var catalog: Dictionary
var profile={"name":"Squidkid","level":1,"xp":0,"weapon":"shooter","sub":"bomb","special":"zooka","skin":1,"outfit":0,"hair":0,"hat":0,"eyes":0,"brows":0}
var settings: Dictionary
var options={"map":"tidewater","mode":"turf","time":"day","duration":180}
var difficulty = 1
var colors = [Color("ff8a14"),Color("2f5bff")]
var state = "menu"
var paused = false
var mode = "turf"
var world: Node3D
var stage: InkStage
var actors: Array = []
var local_actor: InkActor
var combat: InkCombat
var zones: InkZones
var boss: InkBoss
var camera: Camera3D
var hud: InkHUD
var sound: InkSound
var time_left = 180.0
var elapsed = 0.0
var map_open = false
var result: Dictionary = {}
var online = false
var authoritative = true
var peers: Dictionary = {}
var network_status = "No room connected."
var net_timer = 0.0
var loading = false
var headless_test = false
var autoplay = false
var capture_path = ""
var capture_time = 0.0
var smoke_seconds = 0.0
var smoke_done = false
var cli: Dictionary = {}
var model_cache: Dictionary = {}
var camera_shake=0.0
var aim_assist=InkAimAssist.new()
var using_pad=false
var pad_edge_time=0.0
var pad_look=Vector2.ZERO

func _ready():
	get_tree().auto_accept_quit=false
	catalog=InkContent.load_catalog()
	settings=catalog.DEFAULT_SETTINGS.duplicate(true)
	settings.fullscreen=false
	_load_profile()
	setup_input()
	apply_settings()
	for argument in OS.get_cmdline_user_args():
		var parts=argument.trim_prefix("--").split("=",true,1)
		cli[parts[0]]=parts[1] if parts.size()>1 else true
	headless_test=cli.has("smoke") or cli.has("net-test")
	autoplay=cli.has("autoplay") or headless_test
	sound=InkSound.new();add_child(sound);sound.setup(self)
	hud=InkHUD.new();add_child(hud);hud.setup(self)
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func():network_status="Connection failed. Check the host address and UDP port.";online=false;hud.show_menu("online"))
	multiplayer.server_disconnected.connect(func():disconnect_room();return_to_menu();network_status="Host disconnected.";hud.show_menu("online"))
	if cli.has("lang"):settings.lang=cli.lang
	if cli.has("screen"):hud.show_menu(str(cli.screen))
	if cli.has("map"):options.map=cli.map
	if cli.has("mode"):options.mode=cli.mode
	if cli.has("weapon"):
		profile.weapon=cli.weapon;profile.sub=catalog.WEAPONS[profile.weapon].sub;profile.special=catalog.WEAPONS[profile.weapon].special
	if cli.has("sub"):profile.sub=cli.sub
	if cli.has("special"):profile.special=cli.special
	if cli.has("duration"):options.duration=int(cli.duration)
	if cli.has("capture"):capture_path=str(cli.capture);capture_time=float(cli.get("capture-at",5))
	if cli.has("smoke"):smoke_seconds=float(cli.get("seconds",12))
	if cli.has("host"):
		host_room(int(cli.host))
		if cli.has("net-test"):
			for attempt in 100:
				await get_tree().create_timer(0.1).timeout
				if peers.size()>1:break
			start_match()
	elif cli.has("join"):
		join_room(str(cli.join),int(cli.get("port",27840)))
	elif cli.has("autostart") or headless_test:start_match()

func setup_input():
	var keys={"forward":[KEY_W,KEY_UP],"back":[KEY_S,KEY_DOWN],"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"jump":[KEY_SPACE],"swim":[KEY_SHIFT],"sub":[KEY_E],"special":[KEY_F],"map":[KEY_TAB,KEY_M],"pause":[KEY_ESCAPE],"cheer":[KEY_C],"fire":[]}
	for action in keys:
		if not InputMap.has_action(action):InputMap.add_action(action,0.18)
		for key in keys[action]:
			var ev=InputEventKey.new();ev.physical_keycode=key;InputMap.action_add_event(action,ev)
	for pair in [["fire",MOUSE_BUTTON_LEFT],["sub",MOUSE_BUTTON_RIGHT]]:
		var ev=InputEventMouseButton.new();ev.button_index=pair[1];InputMap.action_add_event(pair[0],ev)
	for pair in [["jump",JOY_BUTTON_A],["sub",JOY_BUTTON_RIGHT_SHOULDER],["special",JOY_BUTTON_Y],["map",JOY_BUTTON_BACK],["pause",JOY_BUTTON_START],["cheer",JOY_BUTTON_B]]:
		var ev=InputEventJoypadButton.new();ev.button_index=pair[1];InputMap.action_add_event(pair[0],ev)
	for pair in [["left",JOY_AXIS_LEFT_X,-1],["right",JOY_AXIS_LEFT_X,1],["forward",JOY_AXIS_LEFT_Y,-1],["back",JOY_AXIS_LEFT_Y,1],["fire",JOY_AXIS_TRIGGER_RIGHT,1],["swim",JOY_AXIS_TRIGGER_LEFT,1]]:
		var ev=InputEventJoypadMotion.new();ev.axis=pair[1];ev.axis_value=pair[2];InputMap.action_add_event(pair[0],ev)

func _load_profile():
	var path="user://profile.json"
	if FileAccess.file_exists(path):
		var saved=JSON.parse_string(FileAccess.get_file_as_string(path))
		if saved is Dictionary:
			profile.merge(saved.get("profile",{}),true)
			settings.merge(saved.get("settings",{}),true)
	profile=_valid_profile(profile)

func _valid_profile(p: Dictionary) -> Dictionary:
	var out=profile.duplicate()
	out.name=str(p.get("name","Squidkid")).left(18)
	for pair in [["weapon","WEAPONS","shooter"],["sub","SUBS","bomb"],["special","SPECIALS","zooka"]]:
		var value=str(p.get(pair[0],pair[2]))
		out[pair[0]]=value if catalog[pair[1]].has(value) else pair[2]
	if out.weapon not in catalog.WEAPON_ORDER:out.weapon="shooter"
	out.skin=clampi(int(p.get("skin",1)),0,8)
	out.outfit=clampi(int(p.get("outfit",0)),0,9)
	out.hair=clampi(int(p.get("hair",0)),0,7)
	out.hat=clampi(int(p.get("hat",0)),0,3)
	out.eyes=clampi(int(p.get("eyes",0)),0,7)
	out.brows=clampi(int(p.get("brows",0)),0,3)
	return out

func save_profile():
	if headless_test:return
	var file=FileAccess.open("user://profile.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"profile":profile,"settings":settings}))

func apply_settings():
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.get("fullscreen",false) else DisplayServer.WINDOW_MODE_WINDOWED)
	Engine.max_fps=int(settings.get("fpsCap",0))
	if stage:
		for light in stage.find_children("*","DirectionalLight3D",true,false):light.shadow_enabled=settings.shadows
		for environment in stage.find_children("*","WorldEnvironment",true,false):environment.environment.glow_enabled=settings.bloom
	get_viewport().msaa_3d={"low":Viewport.MSAA_DISABLED,"medium":Viewport.MSAA_2X,"high":Viewport.MSAA_4X,"ultra":Viewport.MSAA_8X}.get(settings.quality,Viewport.MSAA_4X)

func map_name(id: String) -> String:
	for m in catalog.MAPS:
		if m.id==id:return m.name
	return id

func start_match():
	if loading or (online and not authoritative):return
	if online and state=="menu" and not cli.has("net-test"):
		for id in peers:
			if not peers[id].get("ready",false):network_status="Everyone must be ready before the match starts.";hud.show_menu("online");return
	if options.map=="cargo":
		if not online or peers.size()<2:
			network_status="Cargo Terminal requires at least two connected humans."
			hud.show_menu("online")
			return
		if options.mode=="boss":options.mode="turf"
	var roster=[]
	var player_ids=peers.keys() if online else [1]
	player_ids.sort()
	var team_sizes=[0,0]
	for i in 8:
		var human=i<player_ids.size()
		if options.map=="cargo" and not human:continue
		var side=0 if options.mode=="boss" else i%2
		var loadout=profile.duplicate() if i==0 else {}
		var peer=int(player_ids[i]) if human else 0
		if online and human:
			loadout=peers[peer].duplicate()
			var selected=int(loadout.get("room_team",-1))
			if options.mode!="boss" and selected in [0,1] and team_sizes[selected]<4:side=selected
		if options.mode!="boss" and team_sizes[side]>=4:side=1-side
		team_sizes[side]+=1
		if not human:
			var wid=catalog.WEAPON_ORDER[i%12]
			loadout={"name":catalog.BOT_NAMES[(i*3)%catalog.BOT_NAMES.size()],"weapon":wid,"sub":catalog.WEAPONS[wid].sub,"special":catalog.WEAPONS[wid].special,"skin":i%4,"outfit":i%4}
		roster.append({"peer":peer,"team":side,"loadout":loadout})
	if online:net_start.rpc(options,roster,difficulty)
	_build_match(options,roster,difficulty)

@rpc("authority","call_remote","reliable")
func net_start(opts: Dictionary,roster: Array,diff: int):
	_build_match(opts,roster,diff)

func _build_match(opts: Dictionary,roster: Array,diff: int):
	loading=true
	state="loading"
	paused=false
	options=opts.duplicate()
	difficulty=diff
	mode=options.mode
	time_left=float(options.duration)
	elapsed=0
	map_open=false
	actors.clear()
	local_actor=null
	boss=null
	zones=null
	if world:
		world.queue_free()
		await get_tree().process_frame
	world=Node3D.new();world.name="World";add_child(world)
	if settings.colorblind:colors=[Color("ffd21a"),Color("2a52ff")]
	else:colors=[Color("ff8a14"),Color("2f5bff")]
	stage=InkStage.new();world.add_child(stage)
	stage.build(options.map,mode,colors,options.time=="dusk",not headless_test)
	apply_settings()
	combat=InkCombat.new();world.add_child(combat);combat.setup(self)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var own=multiplayer.get_unique_id() if online else 1
	var slots=[0,0]
	for i in roster.size():
		var entry: Dictionary=roster[i]
		var actor=InkActor.new();actor.name="Actor%d"%i;world.add_child(actor)
		actor.peer_id=int(entry.peer)
		actor.spawn_slot=slots[int(entry.team)]
		slots[int(entry.team)]+=1
		actor.setup(self,i,int(entry.team),entry.loadout,int(entry.peer)==own,int(entry.peer)==0)
		if actor.is_local:
			local_actor=actor
			if autoplay:actor.is_bot=true
		actors.append(actor)
	if not local_actor:local_actor=actors[0]
	camera=Camera3D.new();world.add_child(camera);camera.current=true;camera.fov=65;camera.far=600
	if mode=="zones":zones=InkZones.new();world.add_child(zones);zones.setup(self)
	if mode=="boss":boss=InkBoss.new();world.add_child(boss);boss.setup(self)
	for actor in actors:combat.paint_ground(actor.position,2,actor)
	hud.start_hud()
	state="playing"
	loading=false
	hud.banner("MAKE YOUR MARK!")
	_update_camera(1)
	if headless_test:print("MATCH_READY map=%s mode=%s actors=%d turf_cells=%d nav=%d" % [options.map,mode,actors.size(),stage.turf_total,stage.navigation.get_point_count()])
	if online and authoritative:net_ready.rpc()

@rpc("authority","call_remote","reliable")
func net_ready():
	pass

func ray(from: Vector3,to: Vector3,mask: int=1) -> Dictionary:
	var query=PhysicsRayQueryParameters3D.create(from,to,mask)
	query.hit_from_inside=false
	return get_world_3d().direct_space_state.intersect_ray(query)

func paint(pos: Vector3,normal: Vector3,radius: float,a=null,team_override: int=-1):
	var team=team_override if team_override>=0 else a.team
	var gained=stage.paint(pos,normal,radius,team)
	if a:
		a.credit(gained)
		if zones and zones.contains_point(pos):a.zone_turf+=gained
	if online and authoritative:net_paint.rpc(pos,normal,radius,team)

@rpc("authority","call_remote","reliable",1)
func net_paint(pos: Vector3,normal: Vector3,radius: float,team: int):
	if stage and state in ["loading","playing"]:stage.paint(pos,normal,radius,team)

@rpc("authority","call_remote","unreliable",2)
func net_fx(pos: Vector3,team: int,radius: float):
	if combat and state=="playing":combat.explosion_fx(pos,team,radius)

func announce(text: String):
	hud.banner(text)
	if online and authoritative:net_announce.rpc(text)

@rpc("authority","call_remote","reliable")
func net_announce(text: String):hud.banner(text)

func _input(event: InputEvent):
	if state!="playing":return
	if event.is_action_pressed("pause"):
		if paused:resume_match()
		else:paused=true;hud.show_menu("pause")
		return
	if paused:return
	if event is InputEventJoypadMotion or event is InputEventJoypadButton:using_pad=true
	if event is InputEventMouseMotion:using_pad=false
	if elapsed>0.5 and event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and local_actor:
		local_actor.yaw-=event.relative.x*0.0021*float(settings.sensitivity)*(aim_assist.friction if settings.aimAssistMouse else 1.0)
		local_actor.pitch=clampf(local_actor.pitch-event.relative.y*0.0021*float(settings.sensitivity)*(aim_assist.friction if settings.aimAssistMouse else 1.0)*(-1 if settings.invertY else 1),-1.2,1.2)
	if map_open:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode==KEY_0:request_jump(-1)
			if event.keycode>=KEY_1 and event.keycode<=KEY_4:
				var allies=actors.filter(func(a):return a.team==local_actor.team)
				var idx=int(event.keycode-KEY_1)
				if idx<allies.size():request_jump(allies[idx].index)
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:hud.click_map(event.position)

func resume_match():
	paused=false
	if hud.page:hud.page.queue_free();hud.page=null
	hud.screen="hud"
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func _physics_process(dt: float):
	if state!="playing" or loading or (paused and not online):return
	elapsed+=dt
	if not paused and local_actor and not local_actor.is_bot:
		var look=Vector2(Input.get_joy_axis(0,JOY_AXIS_RIGHT_X),Input.get_joy_axis(0,JOY_AXIS_RIGHT_Y)) if not Input.get_connected_joypads().is_empty() else Vector2.ZERO
		aim_assist.update(self,float(settings.aimAssist) if using_pad else (.5 if settings.aimAssistMouse else 0.0))
		var magnitude=clampf((look.length()-.11)/.85,0,1)
		pad_edge_time=minf(.5,pad_edge_time+dt) if magnitude>.93 else maxf(0,pad_edge_time-dt*3)
		var curve=.62*pow(magnitude/.75,1.6) if magnitude<.75 else .62+(magnitude-.75)/.25*.38
		pad_look=pad_look.lerp(look.normalized()*curve,1-exp(-60*dt))
		if magnitude>0 and not map_open:
			var boost=1+.55*clampf((pad_edge_time-.16)/.3,0,1)
			local_actor.yaw-=pad_look.x*dt*3.6*float(settings.padSensitivity)*boost*aim_assist.friction
			local_actor.pitch=clampf(local_actor.pitch-pad_look.y*dt*2.4*float(settings.padSensitivity)*aim_assist.friction*(-1 if settings.invertY else 1),-1.2,1.2)
		if magnitude>0 or Input.get_vector("left","right","forward","back").length()>.2 or Input.is_action_pressed("fire"):
			local_actor.yaw+=aim_assist.motion.x;local_actor.pitch+=aim_assist.motion.y*.7
		var open=Input.is_action_pressed("map") or local_actor.kit.get("strike_aim",false)
		if map_open!=open:
			map_open=open
			Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED
		var command={"move":Input.get_vector("left","right","forward","back"),"yaw":local_actor.yaw,"pitch":local_actor.pitch,"fire":Input.is_action_pressed("fire") and not map_open,"swim":Input.is_action_pressed("swim"),"jump":Input.is_action_just_pressed("jump"),"sub":Input.is_action_just_pressed("sub"),"sub_held":Input.is_action_pressed("sub"),"sub_released":Input.is_action_just_released("sub"),"jump_held":Input.is_action_pressed("jump"),"special":Input.is_action_just_pressed("special"),"cheer":Input.is_action_just_pressed("cheer")}
		if authoritative:local_actor.commands=command
		else:
			net_input.rpc_id(1,command)
			var edges={}
			for key in ["jump","sub_released","special","cheer"]:
				if command.get(key,false):edges[key]=true
			if not edges.is_empty():net_actions.rpc_id(1,edges)
	elif paused and local_actor:local_actor.commands={}
	if online and not authoritative and cli.has("net-test"):
		net_input.rpc_id(1,{"move":Vector2(0,-1),"yaw":local_actor.yaw,"pitch":-0.35,"fire":true,"jump":false,"sub":false,"special":false,"swim":false})
	if authoritative:
		time_left-=dt
		for actor in actors:actor.step(dt)
		combat.step(dt)
		if zones:zones.step(dt)
		if boss:boss.step(dt)
		if time_left<=0 and not zones:
			var coverage=stage.coverage()
			finish_match(1 if mode=="boss" else (0 if coverage[0]>=coverage[1] else 1),"TIME’S UP")
		if online:
			net_timer-=dt
			if net_timer<=0:_send_snapshot();net_timer=0.05
	_update_camera(dt)
	if headless_test and smoke_seconds>0 and elapsed>=smoke_seconds and not smoke_done:
		smoke_done=true
		var report={"map":options.map,"mode":mode,"coverage":stage.coverage(),"shots":combat.shots.size(),"actors":[]}
		for a in actors:report.actors.append({"name":a.nickname,"turf":a.turf,"splats":a.splats,"deaths":a.deaths,"position":[a.position.x,a.position.y,a.position.z]})
		print("SMOKE_RESULT "+JSON.stringify(report))
		get_tree().quit(0 if stage.totals[0]+stage.totals[1]>0 else 1)
	if cli.has("net-test") and elapsed>8:
		print("NET_RESULT peers=%d actors=%d local=%d coverage=%s" % [multiplayer.get_peers().size(),actors.size(),local_actor.index,str(stage.coverage())])
		get_tree().quit()

func _process(dt: float):
	if combat and is_instance_valid(combat):combat.visual_step(dt)
	if state=="playing":
		for a in actors:a.animate(dt)
	hud.update(dt) if hud else null
	if not capture_path.is_empty():
		capture_time-=dt
		if capture_time<=0:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(capture_path)
			print("CAPTURE_SAVED "+capture_path)
			if local_actor:print("CAMERA_DIAG ",camera.position," aim=",local_actor.pitch," yaw=",local_actor.yaw," player=",local_actor.position)
			capture_path=""
			if cli.has("quit-after-capture"):quit_game()

func _update_camera(dt: float):
	if not camera or not local_actor:return
	var a=local_actor
	var focus=a.position+Vector3.UP*(0.7 if a.swim else 1.3)
	var dir=a.forward()
	var right=Vector3(-cos(a.yaw),0,sin(a.yaw))
	var desired=focus-dir*4.1+right*0.55+Vector3.UP*0.45
	var obstruction=ray(focus,desired,1)
	if not obstruction.is_empty():desired=obstruction.position+obstruction.normal*0.2
	camera.global_position=camera.global_position.lerp(desired,1-exp(-18*dt)) if dt<0.5 else desired
	camera.look_at(focus+dir*15)
	camera_shake=maxf(0,camera_shake-dt)
	if camera_shake>0:camera.position+=Vector3(randf_range(-1,1),randf_range(-1,1),0)*camera_shake*float(settings.cameraShake)*0.15
	camera.fov=rad_to_deg(2*atan(tan(deg_to_rad(float(settings.fov))*0.5)/(1440.0/900.0)))

func finish_match(winner: int,reason: String):
	if state!="playing":return
	if online and authoritative:net_finish.rpc(winner,reason)
	_apply_result(winner,reason)

@rpc("authority","call_remote","reliable")
func net_finish(winner: int,reason: String):_apply_result(winner,reason)

func _apply_result(winner: int,reason: String):
	state="results"
	paused=false
	var progression: Dictionary=catalog.PROGRESSION
	var xp=int(progression.xpWin if winner==local_actor.team else progression.xpLose)+int(local_actor.turf*float(progression.zones.turfScale if mode=="zones" else progression.xpPerTurfPoint))+local_actor.splats*int(progression.xpPerSplat)
	if mode=="zones":xp+=int(local_actor.zone_turf*float(progression.zones.xpPerZoneTurfPoint))+(int(progression.zones.xpKnockout) if winner==local_actor.team and reason=="KNOCKOUT" else 0)
	profile.played=int(profile.get("played",0))+1
	if winner==local_actor.team:profile.wins=int(profile.get("wins",0))+1
	profile.xp+=xp
	while profile.xp>=800+profile.level*350:
		profile.xp-=800+profile.level*350
		profile.level+=1
	result={"winner":winner,"reason":reason,"xp":xp}
	save_profile()
	hud.show_menu("results")
	if headless_test:print("MATCH_FINISHED "+JSON.stringify(result));get_tree().quit()

func return_to_menu():
	if online:disconnect_room()
	state="menu"
	paused=false
	actors.clear()
	local_actor=null
	combat=null
	stage=null
	zones=null
	boss=null
	if world:world.queue_free();world=null
	hud.show_menu("main")

func request_jump(index: int):
	if authoritative:_jump(local_actor,index)
	else:net_jump.rpc_id(1,index)

func _jump(actor,index: int):
	if not actor.alive():actor.queued_jump=index;return
	if index==-1:actor.super_jump(stage.spawns[actor.team]);return
	if index< -1:
		for g in combat.gadgets:
			if int(g.id)==-index-2 and g.kind=="beacon" and g.team==actor.team:
				actor.super_jump(g.pos);g.uses-=1
				if g.uses<=0:g.life=0
		return
	if index>=actors.size():return
	var target=actors[index]
	if target.team==actor.team and target.alive():actor.super_jump(target.position)

func host_room(port: int):
	disconnect_room()
	var peer=ENetMultiplayerPeer.new()
	var error=peer.create_server(port,7)
	if error!=OK:network_status="Could not host on UDP %d: %s" % [port,error_string(error)];hud.show_menu("online");return
	multiplayer.multiplayer_peer=peer
	online=true
	authoritative=true
	peers={1:profile.duplicate()}
	peers[1].room_team=0;peers[1].ready=true
	network_status="Hosting on UDP %d. Friends can join using this computer’s IP address." % port
	hud.show_menu("online")

func join_room(address: String,port: int):
	disconnect_room()
	var peer=ENetMultiplayerPeer.new()
	var error=peer.create_client(address,port)
	if error!=OK:network_status=error_string(error);hud.show_menu("online");return
	multiplayer.multiplayer_peer=peer
	online=true
	authoritative=false
	network_status="Connecting to %s:%d…" % [address,port]
	hud.show_menu("online")

func disconnect_room():
	if online:multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new()
	online=false
	authoritative=true
	peers.clear()
	network_status="No room connected."

func _peer_connected(id: int):
	if authoritative and state!="menu":multiplayer.multiplayer_peer.disconnect_peer(id)

func _peer_disconnected(id: int):
	peers.erase(id)
	if authoritative:
		for a in actors:
			if a.peer_id==id:
				a.is_bot=options.map!="cargo";a.peer_id=0
				if options.map=="cargo":a.hp=0;a.respawn=1000000;a.visible=false
		if state=="menu":_broadcast_lobby()

func _connected():net_register.rpc_id(1,profile)

@rpc("any_peer","call_remote","reliable")
func net_register(details: Dictionary):
	if not authoritative or state!="menu":return
	var sender=multiplayer.get_remote_sender_id()
	peers[sender]=_valid_profile(details)
	peers[sender].room_team=-1;peers[sender].ready=cli.has("net-test")
	_broadcast_lobby()

func _broadcast_lobby():
	var names=[]
	for p in peers.values():names.append("%s • %s • %s" % [p.name,["AUTO","ALPHA","BRAVO"][int(p.get("room_team",-1))+1],"READY" if p.get("ready",false) else "CHOOSING"])
	network_status="%d / 8 connected\n%s\nHost chooses the stage and starts the match." % [peers.size(),", ".join(names)]
	net_lobby.rpc(network_status,peers)
	if hud.screen=="online":hud.show_menu("online")

@rpc("authority","call_remote","reliable")
func net_lobby(message: String,roster: Dictionary):
	network_status=message
	peers=roster
	hud.show_menu("online")

@rpc("any_peer","call_remote","unreliable_ordered",2)
func net_input(command: Dictionary):
	if not authoritative or state!="playing":return
	var sender=multiplayer.get_remote_sender_id()
	for a in actors:
		if a.peer_id!=sender:continue
		var move=command.get("move",Vector2.ZERO)
		if not move is Vector2 or not move.is_finite():return
		var yaw_value=float(command.get("yaw",0))
		var pitch_value=float(command.get("pitch",0))
		if not is_finite(yaw_value) or not is_finite(pitch_value):return
		a.commands={"move":move.limit_length(),"yaw":yaw_value,"pitch":clampf(pitch_value,-1.2,1.2)}
		for key in ["fire","swim","jump_held","sub_held"]:a.commands[key]=bool(command.get(key,false))
		return

@rpc("any_peer","call_remote","reliable")
func net_jump(index: int):
	if not authoritative or state!="playing":return
	for a in actors:
		if a.peer_id==multiplayer.get_remote_sender_id():_jump(a,index)

func _send_snapshot():
	var list=[]
	for a in actors:list.append([a.position,a.velocity,a.yaw,a.pitch,a.hp,a.ink,a.special,a.respawn,a.swim,a.firing,a.turf,a.splats,a.deaths,a.special_time,a.charge,a.shield,a.sub_charge,a.kit.get("strike_aim",false)])
	var projectiles=[]
	for s in combat.shots:projectiles.append([s.id,s.pos,s.team,s.kind])
	var devices=[]
	for g in combat.gadgets:devices.append([g.id,g.pos,g.team,g.kind,g.owner,g.uses])
	var zone_state={"counts":zones.counts,"penalties":zones.penalties,"active":zones.active,"controller":zones.controller} if zones else {}
	var boss_state=boss.snapshot() if boss else {}
	net_snapshot.rpc(list,time_left,zone_state,boss_state,projectiles,devices)

@rpc("authority","call_remote","unreliable_ordered",2)
func net_snapshot(list: Array,remaining: float,zone_state: Dictionary,boss_state: Dictionary,projectiles: Array,devices: Array):
	if state!="playing" or actors.size()!=list.size():return
	time_left=remaining
	for i in list.size():
		var a=actors[i];var s=list[i]
		a.network_target=s[0];a.velocity=s[1]
		if not a.is_local:a.yaw=s[2];a.pitch=s[3]
		a.hp=s[4];a.ink=s[5];a.special=s[6];a.respawn=s[7];a.swim=s[8];a.firing=s[9];a.turf=s[10];a.splats=s[11];a.deaths=s[12];a.special_time=s[13];a.charge=s[14];a.shield=s[15];a.sub_charge=s[16];a.kit.strike_aim=s[17]
		a.visible=a.respawn<=0
	if zones and not zone_state.is_empty():
		zones.counts=zone_state.counts;zones.penalties=zone_state.penalties;zones.controller=zone_state.controller
		if zones.active!=int(zone_state.active):zones.active=int(zone_state.active);zones._draw_markers()
	if boss and not boss_state.is_empty():boss.sync_remote(boss_state)
	combat.sync_remote(projectiles,devices)

@rpc("authority","call_remote","reliable",1)
func net_zone_reset(active: int):
	if zones and state=="playing":zones.rotate_to(active)

@rpc("any_peer","call_remote","reliable",3)
func net_actions(edges: Dictionary):
	if not authoritative or state!="playing":return
	for a in actors:
		if a.peer_id!=multiplayer.get_remote_sender_id():continue
		for key in ["jump","sub_released","special","cheer"]:
			if edges.get(key,false)==true:a.pending_edges[key]=true

func request_strike(point: Vector3):
	if authoritative:combat.launch_strike(local_actor,point)
	else:net_strike.rpc_id(1,point)

@rpc("any_peer","call_remote","reliable")
func net_strike(point: Vector3):
	if not authoritative or state!="playing":return
	for a in actors:
		if a.peer_id==multiplayer.get_remote_sender_id():combat.launch_strike(a,point)

func lobby_choice(side: int,ready: bool):
	if not online:return
	if authoritative:
		peers[1]=_valid_profile(profile)
		_lobby_choice(1,side,ready)
	else:net_lobby_choice.rpc_id(1,side,ready,profile)

func _lobby_choice(id: int,side: int,ready: bool):
	if not peers.has(id):return
	side=clampi(side,-1,1)
	var count=0
	for other in peers:
		if other!=id and peers[other].get("room_team",-1)==side:count+=1
	if side>=0 and count>=4:return
	peers[id].room_team=side;peers[id].ready=ready
	_broadcast_lobby()

@rpc("any_peer","call_remote","reliable")
func net_lobby_choice(side: int,ready: bool,details: Dictionary):
	if not authoritative or state!="menu":return
	var sender=multiplayer.get_remote_sender_id()
	if not peers.has(sender):return
	peers[sender]=_valid_profile(details)
	_lobby_choice(sender,side,ready)

func lobby_emote(kind: int):
	if not online:return
	if authoritative:_lobby_emote(1,kind)
	else:net_lobby_emote.rpc_id(1,kind)

func _lobby_emote(id: int,kind: int):
	if not peers.has(id) or kind<0 or kind>3:return
	var text=str(peers[id].name)+" • "+["Yeah!","Nice!","Let's go!","One moment!"][kind]
	hud.banner(text);net_announce.rpc(text)

@rpc("any_peer","call_remote","reliable")
func net_lobby_emote(kind: int):
	if authoritative and state=="menu":_lobby_emote(multiplayer.get_remote_sender_id(),kind)

func _notification(what):
	if what==NOTIFICATION_WM_CLOSE_REQUEST:quit_game()

func quit_game():
	set_physics_process(false)
	if sound:sound.stop_all()
	await get_tree().create_timer(.2).timeout
	get_tree().quit()
