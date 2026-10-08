class_name InkBoss
extends Node3D

var game
var hp=93600.0
var max_hp=93600.0
var phase=1
var age=0.0
var move_time=4.0
var windup=0.0
var move_kind=0
var target_position=Vector3.ZERO
var model: Node3D
var animation: AnimationPlayer
var warning: MeshInstance3D
var nickname="HULLBREAKER"
var splats=0
var team=1
var attack=""
var attack_time=0.0
var attack_duration=0.0
var attack_tick=0.0
var recovery=0.0
var stunned=false
var hazards: Array=[]
var minions: Array=[]
var previous_animation=""
var damage_scale=1.0
var charge_direction=Vector3.ZERO
var barrage_targets: Array=[]
var hit_frames: Dictionary={}
var animation_time=0.0

func setup(owner_game):
	game=owner_game
	hit_frames=JSON.parse_string(FileAccess.get_file_as_string("res://data/boss_hit_shapes.json"))
	var units=0.0
	for a in game.actors:units+=0.6 if a.is_bot and not a.is_local else 1.0
	max_hp=roundf(float(game.catalog.BOSS.hpPerUnit)*maxf(1,units)*[0.75,1.0,1.3][game.difficulty])
	damage_scale=[0.7,1.0,1.2][game.difficulty]
	hp=max_hp
	if not game.stage.nav_points.is_empty():
		position=game.stage.navigation.get_point_position(game.stage.navigation.get_closest_point(Vector3(0,1,0)))
	if not game.headless_test:
		model=load("res://assets/models/hullbreaker.glb").instantiate()
		add_child(model)
		game.stage._prepare_props(model)
		for node in model.find_children("*","AnimationPlayer",true,false):animation=node;break
		var circle=CylinderMesh.new();circle.top_radius=1;circle.bottom_radius=1;circle.height=0.045
		warning=InkContent.mesh(game.world,circle,position,InkContent.material(Color("ff4862"),0.5))
		warning.visible=false
	_play("idle")

func _play(key: String):
	if previous_animation==key:return
	previous_animation=key;animation_time=0
	if not animation:return
	for name in animation.get_animation_list():
		if name==key or name.ends_with("/"+key):
			animation.get_animation(name).loop_mode=Animation.LOOP_LINEAR if key in ["idle","walk"] else Animation.LOOP_NONE
			animation.play(name,0.15);previous_animation=key;return

func damage(amount: float,a,hit_position: Vector3=Vector3.INF,weak_hit: bool=false):
	if hp<=0:return
	var weak=weak_hit
	var multiplier=2.5 if weak else 1.0
	if stunned:multiplier*=1.25
	if a and "weapon_id" in a:multiplier*=float(game.catalog.BOSS.weapon.get(a.weapon_id,1.0))
	hp=maxf(0,hp-amount*multiplier)
	game.sound.effect("boss_crit" if weak else "boss_hit",0.45,hit_position if hit_position!=Vector3.INF else position)
	if hp==0:
		if a:a.splats+=1
		game.combat.explosion_fx(position,1,8)
		game.finish_match(0,"HULLBREAKER DEFEATED")

func step(dt: float):
	if hp<=0:return
	age+=dt
	animation_time+=dt
	phase=1+int(hp<max_hp*0.66)+int(hp<max_hp*0.33)
	_step_hazards(dt)
	_step_minions(dt)
	if recovery>0:
		recovery-=dt
		if recovery<=0:stunned=false;attack="";_play("idle")
		return
	if attack_duration>0:
		attack_time+=dt
		attack_tick-=dt
		_run_attack(dt)
		if attack_time>=attack_duration:
			attack_duration=0
			recovery=maxf(recovery,float(game.catalog.BOSS_MOVES[attack].rec))
			_play(attack+"_rec")
		return
	if windup>0:
		windup-=dt
		if warning:
			warning.visible=true;warning.position=target_position+Vector3.UP*0.08;warning.scale=Vector3.ONE*(3.3+sin(age*18)*0.15)
		if windup<=0:
			if warning:warning.visible=false
			_begin_attack()
		return
	move_time-=dt
	if move_time<=0:
		var live=game.actors.filter(func(a):return a.alive())
		if live.is_empty():return
		var target=live.pick_random()
		target_position=target.position
		var choices=["slam","barrage","sweep","charge"]
		if phase>=2:choices.append("crablets")
		if phase==3:choices.append("frenzy")
		attack=choices.pick_random()
		move_kind=choices.find(attack)
		windup=maxf(0.7,float(game.catalog.BOSS_MOVES[attack].tele)*[1,1,0.88,0.78][phase])
		move_time=randf_range(1.6,3.2)*[1.25,1.0,0.85][game.difficulty]
		var dir=target_position-position;dir.y=0
		charge_direction=dir.normalized()
		if dir.length()>0.1:rotation.y=atan2(dir.x,dir.z)
		barrage_targets=[]
		if attack=="barrage":
			for i in 3+phase:barrage_targets.append(live[i%live.size()].position)
		_play(attack+"_tele")
		game.announce("HULLBREAKER • "+{"slam":"CRUSHER SLAM","barrage":"CONTAINER BARRAGE","sweep":"INK CANNON SWEEP","charge":"HULL CHARGE","crablets":"BROOD","frenzy":"SHELL FRENZY"}[attack])
		return
	var path=game.stage.route(position,target_position)
	if path.size()>1 and position.distance_to(target_position)>7:
		position=position.move_toward(path[1],dt*1.5)
		_play("walk")
	else:_play("idle")

func _begin_attack():
	attack_time=0
	attack_tick=0
	attack_duration=maxf(0.8,float(game.catalog.BOSS_MOVES[attack].act))
	_play(attack+"_act")
	game.sound.effect({"slam":"boss_slam","charge":"boss_gallop","sweep":"boss_cannon_sweep","barrage":"boss_barrel","crablets":"crablet_chitter","frenzy":"boss_frenzy"}.get(attack,"boss_roar"),0.8,position)
	match attack:
		"slam":
			_blast(target_position,3.3,48)
			var ring={"pos":target_position,"age":0.0,"radius":2.4,"hit":{},"mesh":null}
			if not game.headless_test:
				var torus=TorusMesh.new();torus.inner_radius=0.93;torus.outer_radius=1;torus.rings=40;torus.ring_segments=8
				ring.mesh=InkContent.mesh(game.world,torus,target_position+Vector3.UP*0.12,InkContent.material(game.colors[1],0.5))
			hazards.append(ring)
		"charge":attack_duration=minf(2.5,maxf(0.6,position.distance_to(target_position)/13))
		"barrage":attack_duration=barrage_targets.size()*0.26+1.3
		"crablets":
			for i in 3+phase:_spawn_crablet(position+Vector3(cos(i*TAU/5),0,sin(i*TAU/5))*3)

func _run_attack(dt: float):
	match attack:
		"charge":
			var speed=float(game.catalog.BOSS_HAZARDS.chargeSpeed[phase])
			var next=position+charge_direction*speed*dt
			var obstacle=game.ray(position+Vector3.UP*1.5,next+Vector3.UP*1.5+charge_direction*2,1)
			if not obstacle.is_empty():
				attack_time=attack_duration;stunned=true;recovery=4.2
			else:
				var floor_hit=game.ray(next+Vector3.UP*2,next-Vector3.UP*3,1)
				if not floor_hit.is_empty():position=Vector3(next.x,floor_hit.position.y,next.z)
				else:attack_time=attack_duration
			if attack_tick<=0:_blast(position,2.4,55*0.3);attack_tick=0.2
		"sweep":
			if attack_tick<=0:
				var angle=rotation.y+lerpf(-0.7,0.7,attack_time/attack_duration)
				var dir=Vector3(sin(angle),0,cos(angle))
				var start=position+Vector3.UP*1.0
				var end=start+dir*17
				var hit=game.ray(start,end,1)
				if not hit.is_empty():end=hit.position
				for i in 12:
					var p=start.lerp(end,float(i)/12)
					_paint(p,0.8);game.combat.explosion_fx(p,1,0.18)
				for a in game.actors:
					if not a.alive() or a.submerged:continue
					if Geometry3D.get_closest_point_to_segment(a.position+Vector3.UP*0.7,start,end).distance_to(a.position+Vector3.UP*0.7)<0.95:a.take_damage(17*damage_scale,self)
				attack_tick=0.1
		"barrage":
			if attack_time>=1.3 and attack_tick<=0 and not barrage_targets.is_empty():
				_blast(barrage_targets.pop_front(),2.4,52)
				attack_tick=0.26
			if barrage_targets.is_empty():attack_time=attack_duration

		"frenzy":
			rotation.y+=dt*5
			if attack_tick<=0:
				for i in 10:
					var dir=Vector3(cos(i*TAU/10+rotation.y),0,sin(i*TAU/10+rotation.y))
					_paint(position+dir*randf_range(3,8.8),1.2)
				for a in game.actors:
					if a.alive() and a.position.distance_to(position)<8.8 and game.ray(position+Vector3.UP,a.position+Vector3.UP,1).is_empty():a.take_damage(10.4*damage_scale,self)
				attack_tick=0.2

func _step_hazards(dt: float):
	for ring in hazards.duplicate():
		ring.age+=dt;ring.radius=2.4+ring.age*9.5
		if ring.radius>19:
			if ring.mesh:ring.mesh.queue_free()
			hazards.erase(ring);continue
		if ring.mesh:ring.mesh.scale=Vector3(ring.radius,0.2,ring.radius)
		for a in game.actors:
			if not a.alive() or ring.hit.has(a.index):continue
			var d=Vector2(a.position.x-ring.pos.x,a.position.z-ring.pos.z).length()
			if absf(d-ring.radius)<0.65 and a.is_on_floor():a.take_damage(32*damage_scale,self);ring.hit[a.index]=true
		if int(ring.age*10)!=int((ring.age-dt)*10):
			for i in 16:_paint(ring.pos+Vector3(cos(i*TAU/16),0,sin(i*TAU/16))*ring.radius,0.6)

func _spawn_crablet(pos: Vector3):
	var c={"pos":pos,"hp":30.0,"life":12.0,"mesh":null}
	if not game.headless_test:
		c.mesh=load("res://assets/models/crablet.glb").instantiate();game.world.add_child(c.mesh);game.stage._prepare_props(c.mesh);c.mesh.position=pos
	minions.append(c)

func _step_minions(dt: float):
	for c in minions.duplicate():
		c.life-=dt
		if c.hp<=0 or c.life<=0:
			if c.mesh:c.mesh.queue_free()
			minions.erase(c);continue
		var target=null;var distance=INF
		for a in game.actors:
			if a.alive() and a.position.distance_to(c.pos)<distance:target=a;distance=a.position.distance_to(c.pos)
		if not target:continue
		var dir=(target.position-c.pos).normalized()
		var next=c.pos+dir*float(game.catalog.BOSS_HAZARDS.crabSpeed[phase])*dt
		var hit=game.ray(next+Vector3.UP*1.5,next-Vector3.UP*2,1)
		if not hit.is_empty():c.pos=hit.position
		if c.mesh:c.mesh.position=c.pos;c.mesh.rotation.y=atan2(dir.x,dir.z)
		if distance<1.2:_blast(c.pos,2.1,40);c.life=0
		for shot in game.combat.shots:
			if shot.pos.distance_to(c.pos+Vector3.UP*0.3)<0.65:c.hp-=shot.damage;shot.life=0

func _paint(pos: Vector3,radius: float):
	var hit=game.ray(pos+Vector3.UP*4,pos-Vector3.UP*8,1)
	if not hit.is_empty():game.paint(hit.position,hit.normal,radius,null,1)

func _blast(pos: Vector3,radius: float,damage_amount: float):
	_paint(pos,radius)
	game.combat.explosion_fx(pos,1,radius)
	for a in game.actors:
		if a.alive() and a.position.distance_to(pos)<radius and game.ray(pos+Vector3.UP*0.2,a.position+Vector3.UP,1).is_empty():a.take_damage(damage_amount*damage_scale,self)

func segment_hit(start: Vector3,end: Vector3,pad: float=0) -> Dictionary:
	var samples: Array=hit_frames.get(previous_animation,hit_frames.get("idle",[]))
	if samples.is_empty():return {}
	var idx=mini(samples.size()-1,int(animation_time*20))
	if previous_animation in ["idle","walk"]:idx=int(animation_time*20)%samples.size()
	var shapes: Array=samples[idx].duplicate(true)
	for i in minions.size():shapes.append({"socket":"crablet","r":0.5,"weak":false,"active":true,"world":minions[i].pos+Vector3.UP*0.3,"minion":i})
	var delta=end-start
	var length_sq=maxf(0.000001,delta.length_squared())
	var best={};var best_key=INF
	for h in shapes:
		if not h.active and not (h.socket=="belly" and (phase>=3 or stunned)):continue
		var center: Vector3=h.get("world",global_transform*InkContent.vec(h.get("pos",[0,0,0])))
		var t=clampf((center-start).dot(delta)/length_sq,0,1)
		var distance_sq=(start+delta*t).distance_squared_to(center)
		var radius=float(h.r)+pad
		if distance_sq>radius*radius:continue
		var entry=maxf(0,t-sqrt(maxf(0,radius*radius-distance_sq)/length_sq))
		var key=entry-(0.02 if h.weak else 0)
		if key<best_key:
			best_key=key;best={"point":start+delta*entry,"weak":bool(h.weak),"minion":int(h.get("minion",-1)),"distance":delta.length()*entry}
	return best

func apply_segment_damage(hit: Dictionary,amount: float,attacker):
	if hit.minion>=0:
		if hit.minion<minions.size():minions[hit.minion].hp-=amount
	else:damage(amount,attacker,hit.point,hit.weak)

func snapshot() -> Dictionary:
	var rings=[];var crabs=[]
	for ring in hazards:rings.append([ring.pos,ring.radius])
	for crab in minions:crabs.append([crab.pos,crab.hp,crab.mesh.rotation.y if crab.mesh else 0])
	return {"hp":hp,"max_hp":max_hp,"pos":position,"yaw":rotation.y,"phase":phase,"clip":previous_animation,"clip_time":animation_time,"rings":rings,"crabs":crabs,"windup":windup,"target":target_position,"attack":attack}

func sync_remote(s: Dictionary):
	hp=s.hp;max_hp=s.max_hp;position=s.pos;rotation.y=s.yaw;phase=s.phase
	_play(s.clip);animation_time=s.clip_time
	if animation:animation.seek(animation_time,true)
	if warning:warning.visible=float(s.windup)>0;warning.position=s.target+Vector3.UP*0.08;warning.scale=Vector3.ONE*3.3
	while hazards.size()>s.rings.size():
		var ring=hazards.pop_back()
		if ring.mesh:ring.mesh.queue_free()
	while hazards.size()<s.rings.size():
		var mesh=null
		if not game.headless_test:
			var torus=TorusMesh.new();torus.inner_radius=.93;torus.outer_radius=1;torus.rings=40;torus.ring_segments=8
			mesh=InkContent.mesh(game.world,torus,Vector3.ZERO,InkContent.material(game.colors[1],.5))
		hazards.append({"mesh":mesh})
	for i in s.rings.size():
		if hazards[i].mesh:hazards[i].mesh.position=s.rings[i][0]+Vector3.UP*.12;hazards[i].mesh.scale=Vector3(s.rings[i][1],.2,s.rings[i][1])
	while minions.size()>s.crabs.size():
		var crab=minions.pop_back()
		if crab.mesh:crab.mesh.queue_free()
	while minions.size()<s.crabs.size():_spawn_crablet(s.crabs[minions.size()][0])
	for i in s.crabs.size():
		minions[i].pos=s.crabs[i][0];minions[i].hp=s.crabs[i][1]
		if minions[i].mesh:minions[i].mesh.position=s.crabs[i][0];minions[i].mesh.rotation.y=s.crabs[i][2]
