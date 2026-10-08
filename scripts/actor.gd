class_name InkActor
extends CharacterBody3D

var game
var index = 0
var spawn_slot = 0
var team = 0
var nickname = "Squidkid"
var weapon_id = "shooter"
var sub_id = "bomb"
var special_id = "zooka"
var weapon: Dictionary
var is_local = false
var is_bot = true
var peer_id = 0
var hp = 100.0
var ink = 100.0
var special = 0.0
var charge = 0.0
var cooldown = 0.0
var sub_cooldown = 0.0
var hurt_time = 0.0
var fire_idle = 0.0
var respawn = 0.0
var protection = 1.6
var yaw = 0.0
var pitch = -0.12
var swim = false
var submerged = false
var firing = false
var special_time = 0.0
var special_origin = Vector3.ZERO
var special_tick = 0.0
var special_shots = 0
var burst = 0.0
var turret_time = 0.0
var roll_time = 0.0
var roll_velocity = Vector3.ZERO
var brolly_hold = 0.0
var shield = 0.0
var marked = 0.0
var slow = 0.0
var splats = 0
var deaths = 0
var turf = 0.0
var body_model: Node3D
var kid: Node3D
var squid: Node3D
var anim: AnimationPlayer
var label: Label3D
var commands: Dictionary = {}
var path_points = PackedVector3Array()
var path_index = 0
var rethink = 0.0
var last_position = Vector3.ZERO
var stuck = 0.0
var age = 0.0
var jump_target = Vector3.ZERO
var jump_start = Vector3.ZERO
var jump_time = 0.0
var previous_fire = false
var last_anim = ""
var kit: Dictionary = {}
var volley_hits: Dictionary = {}
var volley_serial = 0
var sonar_time = 0.0
var sub_charge = 0.0
var sub_held = false
var cheer_cooldown = 0.0
var coyote = 0.0
var jump_buffer = 0.0
var rolls_used = 0
var roll_reset = 0.0
var mitts_charging = false
var mitts_leaping = false
var mitts_clinging = false
var cling_normal = Vector3.ZERO
var leap_velocity = Vector3.ZERO
var zip_target = Vector3.INF
var zip_hang = 0.0
var zone_turf = 0.0
var network_target=Vector3.INF
var pending_edges: Dictionary={}
var special_model: Node3D
var shown_special=""
var body_shape: CollisionShape3D
var bot_recharging=false
var queued_jump=-100000
var action_animation=""
var action_animation_time=0.0

func next_volley() -> String:
	volley_serial+=1
	return "%d:%d" % [index,volley_serial]


func setup(owner_game, number: int, side: int, loadout: Dictionary, local_player: bool, bot: bool):
	game = owner_game
	index = number
	team = side
	is_local = local_player
	is_bot = bot
	nickname = loadout.get("name","Squidkid")
	weapon_id = loadout.get("weapon","shooter")
	weapon = game.catalog.WEAPONS[weapon_id]
	sub_id = loadout.get("sub",weapon.sub)
	special_id = loadout.get("special",weapon.special)
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(52)
	var cs = CollisionShape3D.new()
	body_shape=cs
	var shape = CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.4
	cs.shape = shape
	cs.position.y = 0.72
	add_child(cs)
	body_model = Node3D.new()
	add_child(body_model)
	if not game.headless_test:
		kid = load("res://assets/models/kid_%s.glb" % weapon_id).instantiate()
		body_model.add_child(kid)
		_tint(kid,loadout)
		anim = _find_anim(kid)
		for skeleton in kid.find_children("*","Skeleton3D",true,false):
			var rig=InkCharacterRig.new();skeleton.add_child(rig);rig.configure(self,weapon_id)
		squid=load("res://assets/models/squid.glb").instantiate()
		body_model.add_child(squid)
		_tint(squid,loadout)
		squid.visible=false
		label=Label3D.new()
		label.text=nickname
		label.font_size=26
		label.pixel_size=0.006
		label.position.y=2.0
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate=game.colors[team].lightened(0.4)
		label.no_depth_test=false
		add_child(label)
	spawn()

func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer: return n
	for child in n.get_children():
		var found=_find_anim(child)
		if found: return found
	return null

func _tint(n: Node, look: Dictionary):
	if n is MeshInstance3D:
		for i in n.mesh.get_surface_count():
			var original=n.get_active_material(i)
			if not original is StandardMaterial3D: continue
			var mat=original.duplicate()
			var mat_name=original.resource_name
			if "TeamInk" in mat_name or "HairInk" in mat_name or "iw-ink" in mat_name:
				mat.albedo_color=game.colors[team]
				if "HairInk" in mat_name:
					var path="res://assets/models/hair_%d_%d.glb" % [int(look.get("hair",0)),int(look.get("hat",0))]
					if ResourceLoader.exists(path):
						var variant=load(path).instantiate()
						for part in variant.find_children("*","MeshInstance3D",true,false):
							if "AppearanceHair" in part.name:n.mesh=part.mesh;break
						variant.free()
					var brow_scene=load("res://assets/models/brows_%d.glb" % int(look.get("brows",0))).instantiate()
					for part in brow_scene.find_children("*","MeshInstance3D",true,false):
						if "AppearanceBrow" in part.name:
							var eyebrow=MeshInstance3D.new();eyebrow.mesh=part.mesh;eyebrow.skin=n.skin;eyebrow.skeleton=n.skeleton
							eyebrow.material_override=InkContent.material(Color("182a32"));n.add_sibling(eyebrow)
							break
					brow_scene.free()
			elif "Skin" in mat_name:
				mat.albedo_color=Color(game.catalog.STYLE.SKIN_TONES[int(look.get("skin",1))])
				mat.vertex_color_use_as_albedo=true
			elif "Outfit" in mat_name:
				var cloth=ShaderMaterial.new();cloth.shader=load("res://shaders/cloth.gdshader")
				var outfit: Dictionary=game.catalog.STYLE.OUTFITS[int(look.get("outfit",0))]
				cloth.set_shader_parameter("team_color",game.colors[team])
				for key in ["shirt","shorts","shoe","sole","sock","strap"]:cloth.set_shader_parameter(key,Color(outfit[key]))
				cloth.set_shader_parameter("pattern",float(outfit.pattern))
				n.set_surface_override_material(i,cloth)
				continue
			elif "Eyes" in mat_name:
				var eyes=ShaderMaterial.new();eyes.shader=load("res://shaders/eyes.gdshader");eyes.set_shader_parameter("iris_color",Color(game.catalog.STYLE.IRIS[int(look.get("eyes",0))][0]));n.set_surface_override_material(i,eyes)
				continue
			else:
				var arrays=n.mesh.surface_get_arrays(i)
				mat.vertex_color_use_as_albedo=arrays[Mesh.ARRAY_COLOR]!=null and arrays[Mesh.ARRAY_COLOR].size()>0
			n.set_surface_override_material(i,mat)
	for child in n.get_children(): _tint(child,look)

func spawn():
	position=game.stage.spawns[team]+Vector3((spawn_slot%4-1.5)*0.85,0.15,float(spawn_slot/4)*0.9)
	velocity=Vector3.ZERO
	hp=100
	ink=100
	protection=1.6
	respawn=0
	visible=true
	yaw=0 if team==0 else PI
	pitch=-0.12
	path_points.clear()
	kit.clear();volley_hits.clear();charge=0;burst=0;shield=0
	mitts_charging=false;mitts_leaping=false;mitts_clinging=false
	sub_held=false;sub_charge=0;previous_fire=false;rolls_used=0;roll_reset=0;turret_time=0
	zip_target=Vector3.INF;zip_hang=0;sonar_time=0
	if queued_jump!=-100000:
		var target=queued_jump;queued_jump=-100000;game.call_deferred("_jump",self,target)

func forward() -> Vector3:
	return Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))

func alive() -> bool:
	return respawn<=0 and hp>0

func step(dt: float):
	age+=dt
	if respawn>0:
		respawn-=dt
		if respawn<=0: spawn()
		return
	if jump_time>0:
		jump_time=maxf(0,jump_time-dt)
		var t=1-jump_time/1.8
		position=jump_start.lerp(jump_target,t)+Vector3.UP*sin(t*PI)*18
		protection=0.5
		return
	cooldown=maxf(0,cooldown-dt)
	sub_cooldown=maxf(0,sub_cooldown-dt)
	hurt_time=maxf(0,hurt_time-dt)
	protection=maxf(0,protection-dt)
	marked=maxf(0,marked-dt)
	sonar_time=maxf(0,sonar_time-dt)
	cheer_cooldown=maxf(0,cheer_cooldown-dt)
	kit.guard=maxf(0,float(kit.get("guard",0))-dt)
	roll_reset=maxf(0,roll_reset-dt)
	if roll_reset<=0:rolls_used=0
	for key in volley_hits.keys():
		if volley_hits[key]<age:volley_hits.erase(key)
	slow=maxf(0,slow-dt)
	turret_time=maxf(0,turret_time-dt)
	fire_idle+=dt
	if is_bot: _bot_input(dt)
	commands.merge(pending_edges,true);pending_edges.clear()
	var move: Vector2=commands.get("move",Vector2.ZERO)
	yaw=float(commands.get("yaw",yaw))
	pitch=clampf(float(commands.get("pitch",pitch)),-1.25,1.25)
	firing=commands.get("fire",false)
	swim=commands.get("swim",false) and not firing
	collision_mask=1 if swim else 5
	body_shape.shape.height=0.64 if swim else 1.4
	body_shape.position.y=0.34 if swim else 0.72
	coyote=float(game.catalog.PLAYER.coyoteTime) if is_on_floor() else maxf(0,coyote-dt)
	jump_buffer=float(game.catalog.PLAYER.jumpBuffer) if commands.get("jump",false) else maxf(0,jump_buffer-dt)
	if commands.get("cheer",false) and cheer_cooldown<=0:
		cheer_cooldown=0.6
		game.combat.cheer(self)
		action_animation="cheer";action_animation_time=.6
	if commands.get("move",Vector2.ZERO).length()>0.15 and roll_time<=0:turret_time=0
	var ground_ink=game.stage.ink_at(position+Vector3.UP*0.06)
	submerged=swim and ground_ink==team and is_on_floor()
	var enemy_ink=ground_ink==1-team and is_on_floor()
	var speed=11.8 if submerged else (2.9 if swim else 6.0)
	if enemy_ink:
		speed=1.9
		if hp>60:hp=maxf(60,hp-20*dt)
		hurt_time=maxf(hurt_time,0.1)
	if firing and not swim: speed=float(weapon.get("moveSpeedFiring",4.6))
	if slow>0: speed*=0.55
	if sonar_time>0: speed*=0.8
	if charge>0:speed=float(weapon.get("moveSpeedDrawing",weapon.get("moveSpeedCharging",weapon.get("moveSpeedFiring",speed))))
	if weapon_id=="brolly" and shield>0:speed=weapon.moveSpeedShield
	if firing and previous_fire and weapon_id in ["roller","brush"] and cooldown<=0.25:speed=float(weapon.get("rollSpeed",weapon.get("brushSpeed",speed)))
	if mitts_charging:speed=weapon.moveSpeedCharging
	if special_time>0:
		special_time=maxf(0,special_time-dt)
		game.combat.special_step(self,dt)
		if special_id=="kraken":
			speed=7.2
			if firing:game.combat._special_fire(self,true,dt,forward())
		if special_id=="crab": speed=9.5 if swim else 3.0
		if special_id=="booyah":speed=1.8
		if special_id=="wail":speed=3.2
		if special_id=="sonar" or kit.get("strike_aim",false):speed=0
		if special_time==0 and special_id in ["jetpack","zipcaster"]: super_jump(special_origin)
	if hurt_time==0: hp=minf(100,hp+(60 if submerged else 22)*dt)
	if submerged or fire_idle>0.9:
		ink=minf(100,ink+(42 if submerged else 9)*dt)
	var f=Vector3(sin(yaw),0,cos(yaw))
	var right=Vector3(-cos(yaw),0,sin(yaw))
	var target=(right*move.x-f*move.y)*speed
	var acceleration=64.0 if submerged else (70.0 if is_on_floor() else 20.0)
	velocity.x=move_toward(velocity.x,target.x,acceleration*dt)
	velocity.z=move_toward(velocity.z,target.z,acceleration*dt)
	var gravity=25.0*(1.2 if velocity.y<0 else 1.0)*(0.82 if absf(velocity.y)<1.6 else 1.0)
	velocity.y=maxf(-40,velocity.y-gravity*dt)
	var mitts_jump=weapon_id=="mitts" and firing and special_time<=0
	if mitts_jump and commands.get("jump",false) and not mitts_leaping and ink>=weapon.leapInkMin:
		mitts_charging=true;charge=0;jump_buffer=0
	if mitts_charging:
		charge=minf(1,charge+dt/float(weapon.leapChargeTime));fire_idle=0
		if not commands.get("jump_held",commands.get("jump",false)):
			var angle=clampf(deg_to_rad(weapon.leapAngle)+pitch*float(weapon.leapPitchK),deg_to_rad(weapon.leapAngleMin),deg_to_rad(weapon.leapAngleMax))
			var power=sqrt(lerpf(pow(weapon.leapSpeedMin,2),pow(weapon.leapSpeedMax,2),charge))
			var heading=Vector3(sin(yaw),0,cos(yaw))
			if mitts_clinging and heading.dot(cling_normal)<0.35:heading=(heading+cling_normal*(0.35-heading.dot(cling_normal))).normalized()
			if InkWeaponRunner.spend(self,lerpf(weapon.leapInkMin,weapon.leapInkMax,charge)):
				velocity=heading*power*cos(angle)+Vector3.UP*minf(weapon.leapVyMax,power*sin(angle))
				leap_velocity=Vector3(velocity.x,0,velocity.z);mitts_leaping=true;coyote=0
				game.sound.effect("mitts_leap",0.65)
			mitts_charging=false;mitts_clinging=false;charge=0
	if jump_buffer>0 and coyote>0 and not mitts_jump and not mitts_charging:
		jump_buffer=0;coyote=0
		velocity.y=9.4 if submerged else 8.4
		if firing and weapon_id=="twins" and ink>=7 and rolls_used<int(weapon.rollCharges):
			rolls_used+=1;roll_reset=weapon.rollLockout if rolls_used>=int(weapon.rollCharges) else weapon.rollReset
			roll_time=0.3
			roll_velocity=(target.normalized() if target.length()>0.1 else right)*11.3
			ink-=7
			turret_time=1.4
	if roll_time>0:
		roll_time-=dt
		velocity.x=roll_velocity.x
		velocity.z=roll_velocity.z
	# The same wall paint atlas governs climbing and floor swimming.
	if swim and move.length()>0.1:
		var hit=game.ray(position+Vector3.UP*0.5,position+Vector3.UP*0.5+target.normalized()*0.65,1)
		if not hit.is_empty() and absf(hit.normal.y)<0.3 and game.stage.ink_at(hit.position,hit.normal)==team:
			velocity.y=7.5
			submerged=true
			ink=minf(100,ink+42*dt)
	if special_time>0 and special_id=="jetpack":
		kit.jet_boost=maxf(0,float(kit.get("jet_boost",0))-dt)
		if commands.get("jump",false) and kit.jet_boost<=0:velocity.y=9;kit.jet_boost=.9
		elif kit.jet_boost<.6:velocity.y=clampf((special_origin.y+3.8-position.y)*4,-4,6)
	if special_time>0 and special_id=="slam":
		var phase=float(kit.get("slam_age",0))
		velocity.x=0;velocity.z=0
		velocity.y=10 if phase<.55 else (0 if phase<.8 else -32)
	if mitts_leaping:
		velocity.x=leap_velocity.x;velocity.z=leap_velocity.z
	if mitts_clinging:
		velocity=Vector3.ZERO;ink=maxf(0,ink-float(weapon.clingDrain)*dt);fire_idle=0
		if ink<=0 or swim or (commands.get("jump",false) and not firing):mitts_clinging=false;velocity=cling_normal*2+Vector3.UP*3
	if zip_target!=Vector3.INF:
		velocity=(zip_target-position).normalized()*22
		if position.distance_to(zip_target)<0.5:
			position=zip_target;zip_target=Vector3.INF;zip_hang=1.4;velocity=Vector3.ZERO
			game.combat.explode(position,self,2.4,100,30)
	elif zip_hang>0:
		zip_hang-=dt;velocity=Vector3.ZERO
		if commands.get("jump",false) or swim:zip_hang=0
	move_and_slide()
	if special_time>0 and special_id=="slam" and kit.get("slam_age",0)>.8 and is_on_floor():
		game.combat.explode(position,self,5.2,180,55,-1,3.2);special_time=0
		game.sound.effect("slam_impact",.8,position)
	if mitts_leaping and (is_on_floor() or is_on_wall()):
		mitts_leaping=false;protection=maxf(protection,float(weapon.landInvuln))
		game.combat.explode(position,self,weapon.landRadius,weapon.landDamageMax,weapon.landDamageMin)
		game.sound.effect("mitts_land",0.7)
		if is_on_wall() and not is_on_floor():
			cling_normal=get_wall_normal()
			var wall=game.ray(position+Vector3.UP*1.35,position+Vector3.UP*1.35-cling_normal*0.85,1)
			if not wall.is_empty():mitts_clinging=true
	if position.y < -1.45: take_damage(1000,null,true)
	if not alive(): return
	if commands.get("special",false):game.combat.activate_special(self)
	if not swim:
		game.combat.main_weapon(self,dt,firing,previous_fire)
		var holding=bool(commands.get("sub_held",false))
		if holding and not sub_held:sub_charge=0
		if holding and sub_id=="shaker":
			var d: Dictionary=game.catalog.SUBS.shaker
			var rate=minf(d.maxRate,1+float(d.moveBoost)*minf(1,move.length()))
			sub_charge=minf(1,sub_charge+dt*rate/float(d.chargeTime)+(float(d.jumpBoost) if commands.get("jump",false) else 0))
		if (commands.get("sub_released",false) or (commands.get("sub",false) and not holding)) and sub_cooldown<=0:game.combat.throw_sub(self)
		sub_held=holding
	previous_fire=firing
	for key in ["jump","sub","sub_released","special","cheer"]: commands[key]=false

func animate(dt: float):
	if network_target!=Vector3.INF:
		position=position.lerp(network_target,1-exp(-20*dt)) if position.distance_to(network_target)<8 else network_target
	if not body_model: return
	body_model.rotation.y=lerp_angle(body_model.rotation.y,yaw,1-exp(-18*dt))
	if kid:
		var prop_id={"crab":"crab","jetpack":"jetpack","kraken":"kraken","wail":"speaker"}.get(special_id,"") if special_time>0 else ""
		if shown_special!=prop_id:
			if special_model:special_model.queue_free();special_model=null
			shown_special=prop_id
			if not prop_id.is_empty():
				special_model=load("res://assets/models/special_"+prop_id+".glb").instantiate();body_model.add_child(special_model);_tint(special_model,{})
				if prop_id=="jetpack":special_model.position=Vector3(0,0.9,-0.2)
				if prop_id=="speaker":special_model.position=Vector3(0,1,0.6)
		kid.position.y=1.0 if prop_id=="crab" else 0
		kid.visible=not swim and prop_id!="kraken"
		squid.visible=swim and prop_id!="kraken"
		squid.scale=Vector3.ONE*(1.8 if special_time>0 and special_id=="kraken" else 1.0)
		squid.rotation.z=sin(age*14)*0.07*minf(1,velocity.length()/6)
		action_animation_time=maxf(0,action_animation_time-dt)
		var state="charge" if charge>0.1 else ("fire" if firing else ("run" if Vector2(velocity.x,velocity.z).length()>0.4 else "idle"))
		if not is_on_floor() and not swim:state="air"
		if roll_time>0:state="roll"
		if action_animation_time>0:state=action_animation
		if anim and state!=last_anim:
			for key in anim.get_animation_list():
				if key==state or key.ends_with("/"+state):
					anim.get_animation(key).loop_mode=Animation.LOOP_LINEAR
					anim.play(key,0.12)
					break
			last_anim=state
		body_model.visible=alive() and (protection<=0 or fmod(age,0.16)>0.04)
		if label: label.visible=not is_local and alive() and (team==game.local_actor.team or not submerged or marked>0)

func take_damage(amount: float, attacker, ignore_protection: bool = false,hit_from: Vector3=Vector3.INF):
	if not alive() or (protection>0 and not ignore_protection): return
	var source=hit_from if hit_from!=Vector3.INF else (attacker.position if attacker else position-forward())
	var incoming=(source-position).normalized()
	var front=Vector3(sin(yaw),0,cos(yaw)).dot(incoming)
	if special_time>0 and special_id in ["bubbler","kraken"] and not ignore_protection:
		velocity-=incoming*minf(6.5,amount*(0.045 if special_id=="bubbler" else 0.02))
		return
	if not ignore_protection:
		if special_time>0 and special_id=="stamp" and kit.get("guard",0)>0 and front>cos(deg_to_rad(70)):return
		if weapon_id=="mitts" and (kit.get("guard",0)>0 or mitts_leaping) and front>cos(deg_to_rad(weapon.guardArc)):
			amount*=1-float(weapon.leapArmor if mitts_leaping else weapon.guardArmor)
		var protected=front>0.15 and source.y<position.y+2.0
		if special_time>0 and special_id=="crab" and swim:amount*=0.35;protected=true
		if shield>0 and protected:
			shield=maxf(0,shield-amount)
			if weapon_id=="brolly":
				kit.canopy_hp=shield
				if shield<=0:kit.regrow=weapon.regrowTime;kit.canopy_hp=weapon.canopyHp
			return
	hp-=amount
	action_animation="hurt";action_animation_time=.25
	hurt_time=1.3
	if is_local:
		game.hud.hit_flash=0.25
		game.camera_shake=maxf(game.camera_shake,0.2)
		if not Input.get_connected_joypads().is_empty():Input.start_joy_vibration(0,0.25*float(game.settings.rumble),0.6*float(game.settings.rumble),0.15)
	if hp>0: return
	hp=0
	deaths+=1
	respawn=5.5
	special*=0.5
	special_time=0
	shield=0
	visible=false
	if attacker!=null and attacker!=self:
		attacker.splats+=1
		game.announce("%s splatted %s" % [attacker.nickname,nickname])
	else: game.announce("%s went overboard" % nickname)
	game.combat.explosion_fx(position+Vector3.UP*0.7,team,1.1)
	game.sound.effect("splat",0.55)

func credit(amount: float):
	turf+=amount
	if special_time<=0: special=minf(float(weapon.specialCost),special+amount*0.8)

func super_jump(destination: Vector3):
	if not alive() or jump_time>0: return
	jump_start=position
	jump_target=destination+Vector3.UP*0.15
	jump_time=1.8
	game.sound.effect("jump",0.5)

func _bot_input(dt: float):
	rethink-=dt
	stuck=stuck+dt if position.distance_to(last_position)<0.025 else 0
	last_position=position
	var foe=null
	var nearest=28.0
	for a in game.actors:
		if a.team==team or not a.alive() or a.submerged: continue
		var dist=position.distance_to(a.position)
		if dist<nearest:
			var sight=game.ray(position+Vector3.UP, a.position+Vector3.UP,1)
			if sight.is_empty():
				nearest=dist
				foe=a
	if rethink<=0 or path_index>=path_points.size():
		rethink=randf_range(1.5,3.5)
		var destination=game.stage.nav_points.pick_random() if not game.stage.nav_points.is_empty() else Vector3.ZERO
		if game.mode=="zones": destination=game.zones.target_position()+Vector3(randf_range(-3,3),0,randf_range(-3,3))
		elif game.mode=="boss" and game.boss: destination=game.boss.position+Vector3(randf_range(-4,4),0,randf_range(-4,4))
		elif foe: destination=foe.position
		elif randf()<0.55: destination=game.stage.spawns[1-team].lerp(Vector3.ZERO,randf_range(0.5,0.9))
		path_points=game.stage.route(position,destination)
		path_index=1 if path_points.size()>1 else 0
	var direction=Vector3.ZERO
	if path_index<path_points.size():
		direction=path_points[path_index]-position
		if Vector2(direction.x,direction.z).length()<0.8: path_index+=1
	var aim_direction=direction
	var shoot=ink>15
	var accuracy=[0.2,0.08,0.025][game.difficulty]
	if foe:
		aim_direction=(foe.position+Vector3.UP*0.85)-(position+Vector3.UP)
		aim_direction+=Vector3(randf_range(-accuracy,accuracy),randf_range(-accuracy,accuracy),0)*nearest
		shoot=nearest<float(weapon.get("range",weapon.get("rangeMax",11)))+2 and ink>4
	elif game.mode=="boss" and game.boss and position.distance_to(game.boss.position)<25:
		aim_direction=game.boss.position+Vector3.UP*2-position-Vector3.UP
	else:
		aim_direction=Vector3(direction.x,0,direction.z).normalized()*7
		aim_direction.y=-2.7
	if aim_direction.length()>0.1:
		yaw=lerp_angle(yaw,atan2(aim_direction.x,aim_direction.z),dt*6)
		pitch=lerpf(pitch,atan2(aim_direction.y,Vector2(aim_direction.x,aim_direction.z).length()),dt*6)
	var f=Vector3(sin(yaw),0,cos(yaw))
	var r=Vector3(-cos(yaw),0,sin(yaw))
	var dir=Vector3(direction.x,0,direction.z).normalized()
	var own_ink=game.stage.ink_at(position)==team
	if ink<20:bot_recharging=true
	if ink>85:bot_recharging=false
	var recharge=bot_recharging
	if recharge and own_ink: dir=Vector3.ZERO
	commands={"move":Vector2(dir.dot(r),-dir.dot(f)),"yaw":yaw,"pitch":pitch,"fire":shoot and not recharge,"swim":recharge,"jump":stuck>0.45 or direction.y>0.7,"sub":foe!=null and ink>80 and randf()<dt*0.3,"special":special>=float(weapon.specialCost)}
	if weapon_id in ["charger","bow","blade","spinner"] and charge>=0.999: commands.fire=false
	if weapon_id=="mitts" and foe and special_time<=0:
		var want=nearest>4 and nearest<14 and ink>30 and randf()<dt*.6
		commands.jump=want and not mitts_charging and not mitts_leaping
		commands.jump_held=commands.jump or (mitts_charging and charge<.999)
	if weapon_id=="brolly" and brolly_hold>1.0:commands.fire=false
	if stuck>2.5:
		rethink=0
		stuck=0
