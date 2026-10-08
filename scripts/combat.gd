class_name InkCombat
extends Node3D

var game
var shots: Array = []
var gadgets: Array = []
var effects: Array = []
var projectile_materials: Array = []
var effect_mesh: SphereMesh
var serial = 0
var remote_visuals: Dictionary = {}

func setup(owner_game):
	game=owner_game
	for c in game.colors: projectile_materials.append(InkContent.material(c,0.1))
	effect_mesh=SphereMesh.new()
	effect_mesh.radius=1
	effect_mesh.height=2
	effect_mesh.radial_segments=12
	effect_mesh.rings=6

func emit_shot(actor, direction: Vector3, speed: float, damage: float, radius: float, reach: float, gravity: float = 9, splash: float = 0, kind: String = "ink", extra: Dictionary = {}):
	var pos=actor.position+Vector3.UP*1.04+direction*0.55
	serial+=1
	var s={"id":serial,"pos":pos,"vel":direction*speed,"damage":damage,"radius":radius,"reach":reach,"traveled":0.0,"gravity":gravity,"splash":splash,"kind":kind,"owner":actor.index,"team":actor.team,"age":0.0,"life":4.0,"bounces":0,"armed":false,"fuse":-1.0,"trail":0.0,"hit_ids":[],"direct_id":-1}
	s.merge(extra,true)
	s.mesh=null
	if not game.headless_test:
		var n=device_visual(kind,actor.team,pos)
		var original_device=n.has_meta("source_device")
		if not original_device:n.scale=Vector3.ONE*(1.5 if kind=="bubble" else (0.15 if kind=="ink" else 0.27))
		s.mesh=n
	shots.append(s)

func aim(actor) -> Vector3:
	if actor.is_local and not game.headless_test:
		var from=game.camera.global_position
		var direction=-game.camera.global_basis.z
		var hit=game.ray(from,from+direction*100,1)
		var target=hit.position if not hit.is_empty() else from+direction*100
		return (target-actor.position-Vector3.UP*1.04).normalized()
	return actor.forward()

func main_weapon(a, dt: float, held: bool, was_held: bool):
	if a.special_time>0 and a.special_id in ["zooka","jetpack","crab","stamp","kraken","wail","blower","booyah"]:
		_special_fire(a,held,dt,aim(a))
		return
	InkWeaponRunner.update(self,a,dt,held,was_held)

func spread(direction: Vector3, degrees: float) -> Vector3:
	return direction.rotated(Vector3.UP,deg_to_rad(randf_range(-degrees,degrees))).rotated(Vector3.RIGHT,deg_to_rad(randf_range(-degrees,degrees))*0.5).normalized()

func beam(a, direction: Vector3, distance: float, damage: float, radius: float, through: bool = false, stop_on_actor: bool = false):
	var start=a.position+Vector3.UP
	var end=start+direction*distance
	var hit=game.ray(start,end,1)
	if not through and not hit.is_empty(): end=hit.position
	if not through:
		var block=blocking_device(start,end,a.team,damage)
		if not block.is_empty():end=block.position
	if stop_on_actor:
		var nearest=start.distance_to(end)
		for other in game.actors:
			if other.team==a.team or not other.alive():continue
			var center=other.position+Vector3.UP*0.7
			var closest=Geometry3D.get_closest_point_to_segment(center,start,end)
			if closest.distance_to(center)<radius+0.38:nearest=minf(nearest,start.distance_to(closest))
		end=start+direction*nearest
	var length=start.distance_to(end)
	for i in range(ceili(length/0.7)):
		var point=start+direction*i*0.7
		paint_ground(point,radius,a)
		if i%3==0: explosion_fx(point,a.team,0.17)
	for other in game.actors:
		if other.team==a.team or not other.alive(): continue
		var closest=Geometry3D.get_closest_point_to_segment(other.position+Vector3.UP*0.7,start,end)
		if closest.distance_to(other.position+Vector3.UP*0.7)<radius+0.35: other.take_damage(damage,a)
	if game.boss:
		var boss_hit=game.boss.segment_hit(start,end,radius)
		if not boss_hit.is_empty():game.boss.apply_segment_damage(boss_hit,damage,a)
	if not hit.is_empty() and not through: game.paint(hit.position,hit.normal,radius,a)

func melee(a, direction: Vector3, reach: float, damage: float, radius: float):
	paint_ground(a.position+direction*reach*0.5,radius,a)
	for other in game.actors:
		if other.team==a.team or not other.alive(): continue
		var d=other.position-a.position
		if d.length()<reach+0.4 and d.normalized().dot(direction)>0.2:
			if game.ray(a.position+Vector3.UP,other.position+Vector3.UP,1).is_empty(): other.take_damage(damage,a)
	if game.boss and game.boss.position.distance_to(a.position)<reach+3: game.boss.damage(damage,a)

func paint_ground(pos: Vector3, radius: float, a):
	var hit=game.ray(pos+Vector3.UP*0.5,pos-Vector3.UP*7,1)
	if not hit.is_empty(): game.paint(hit.position,hit.normal,radius,a)

func throw_sub(a):
	var dir=aim(a)
	if a.special_time>0 and a.special_id=="zipcaster":
		var hit=game.ray(a.position+Vector3.UP,a.position+Vector3.UP+dir*21,1)
		if not hit.is_empty():
			a.zip_target=hit.position+hit.normal*0.65
			a.zip_hang=0
			a.sub_cooldown=0.35
		return
	if a.special_time>0 and a.special_id=="crab":
		emit_shot(a,(dir+Vector3.UP*0.25).normalized(),17,150,2,28,15,3)
		a.sub_cooldown=1.15
		return
	if a.special_time>0 and a.special_id=="stamp":
		emit_shot(a,dir,25,200,2,40,4,3.2)
		a.special_time=0
		return
	var sub=a.sub_id
	var free=a.special_time>0 and a.special_id.begins_with("barrage")
	if free: sub=game.catalog.SPECIALS[a.special_id].bomb
	var def: Dictionary=game.catalog.SUBS[sub]
	if sub in ["torpedo","boomerang"]:
		for shot in shots:
			if shot.owner==a.index and shot.kind==sub:return
	if not free and not InkWeaponRunner.spend(a,float(def.inkCost)):return
	a.fire_idle=0
	a.sub_cooldown=float(game.catalog.SPECIALS[a.special_id].get("gap",0.4)) if free else 0.65
	if sub in ["mine","beacon"]:
		var same=[]
		for g in gadgets:
			if g.owner==a.index and g.kind==sub: same.append(g)
		if same.size()>=int(def.get("max",3)): same[0].life=0
		deploy(sub,a.position,a)
	elif sub=="tracer":
		emit_shot(a,dir.rotated(Vector3.RIGHT,0.12),40,35,1.35,32,0,0,"tracer",{"life":1.3})
	else:
		emit_shot(a,(dir+Vector3.UP*0.3).normalized(),float(def.get("throwSpeed",13)),float(def.get("damageMax",def.get("directDamage",0))),float(def.get("paintRadius",1)),45,24,float(def.get("radius",0)),sub,{"fuse":float(def.get("fuse",1)),"life":float(def.get("life",7)),"blasts":1+mini(2,int(a.sub_charge*2.999)),"normal":Vector3(sin(a.yaw),0,cos(a.yaw))})
	a.action_animation="throw";a.action_animation_time=.4
	game.sound.effect("throw",0.35,a.position)

func deploy(kind: String, pos: Vector3, a, extra: Dictionary = {}):
	serial+=1
	var g={"id":serial,"kind":kind,"pos":pos,"owner":a.index,"team":a.team,"life":30.0,"age":0.0,"tick":0.0,"hp":70.0,"vel":Vector3.ZERO,"uses":2,"normal":Vector3(sin(a.yaw),0,cos(a.yaw)),"width":3.4,"height":2.7}
	if kind=="curtain":g.life=170.0/19.0;g.hp=170.0
	if kind=="beacon":g.life=3600;g.hp=50
	if kind in ["mine","sprinkler"]:g.life=3600
	if kind=="mist":g.life=4.5
	if kind=="scan":g.life=0.9
	g.merge(extra,true)
	g.mesh=null
	if not game.headless_test:
		var mat=projectile_materials[a.team].duplicate()
		if kind in ["mist","storm","bubbler","curtain"]:
			mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a=0.3
		var n=device_visual(kind,a.team,pos+Vector3.UP*0.2)
		if not n.has_meta("source_device"):n.scale=Vector3(0.3,0.3,0.3)
		if kind in ["curtain","canopy"]:n.scale=Vector3(1.7,1.4,0.12);n.position.y+=1.2;n.rotation.y=a.yaw
		if kind in ["mist","scan","storm","strike"]: n.scale=Vector3(3.3,0.5,3.3)
		if kind=="storm":n.position.y+=5
		g.mesh=n
	gadgets.append(g)

func activate_special(a):
	if a.special<float(a.weapon.specialCost) or a.special_time>0: return
	a.special=0
	a.ink=100
	a.special_origin=a.position
	a.special_time=float(game.catalog.SPECIALS[a.special_id].get("duration",3.0))
	a.special_tick=0
	a.special_shots=0
	game.announce(a.nickname+" • "+str(game.catalog.SPECIALS[a.special_id].name))
	game.sound.effect("special",0.6)
	match a.special_id:
		"slam":
			a.velocity.y=10;a.kit.slam_age=0.0;a.special_time=4
		"storm": deploy("storm",a.position+aim(a)*10,a,{"life":6.5,"vel":aim(a)*1.1})
		"strike":
			a.kit.strike_aim=true;a.special_time=7
			if a.is_bot:
				var hit=game.ray(a.position+Vector3.UP,a.position+Vector3.UP+aim(a)*50,1)
				launch_strike(a,hit.position if not hit.is_empty() else a.position+aim(a)*18)
		"sonar":
			a.special_time=.6
			for other in game.actors:
				if other.team!=a.team: other.marked=8;other.sonar_time=8
		"crab": a.shield=460
		"wail":a.special_time=10.5;a.kit.wail_charge=-1.0
		"booyah": a.special_time=7.2

func special_step(a, dt: float):
	if a.special_id=="slam":a.kit.slam_age=float(a.kit.get("slam_age",0))+dt
	if a.special_id=="strike" and a.kit.get("strike_aim",false) and a.special_time<=0.05:launch_strike(a,a.position)
	if a.special_id=="bubbler":
		for other in game.actors:
			if other.team==a.team and other.position.distance_to(a.position)<1.5: other.protection=maxf(other.protection,0.2)
	if a.special_id=="kraken":
		a.swim=true
		paint_ground(a.position,1.15,a)
	if a.special_id=="booyah":
		a.special_tick+=dt
		if a.special_tick>=4.5 and ((a.firing and not a.previous_fire) or a.special_tick>=7 or a.is_bot):
			emit_shot(a,aim(a),19.6,220,8.4,40,24,8.4,"sticky",{"fuse":1.5,"inner":4.6,"splash_min":60})
			a.special_time=0
	if a.special_id=="crab" and a.shield<=0: a.special_time=0

func _special_fire(a,held: bool,dt: float,dir: Vector3):
	if a.special_id=="wail":
		if held and float(a.kit.get("wail_charge",-1))<0:a.kit.wail_charge=0.0
		if float(a.kit.get("wail_charge",-1))>=0:
			a.kit.wail_charge+=dt
			if a.kit.wail_charge>1.3 and a.cooldown<=0:beam(a,dir,72,26,1.5,true);a.cooldown=0.1
			if a.kit.wail_charge>=4.5:a.special_time=0
		return
	if not held or a.cooldown>0: return
	match a.special_id:
		"zooka": emit_shot(a,dir,34,180,1,44,0,1.1);a.cooldown=1.0
		"jetpack": emit_shot(a,dir,30,125,1.5,34,0,2.4,"ink",{"splash_damage":70,"splash_min":30,"exclude_direct":true});a.cooldown=0.55
		"crab": emit_shot(a,spread(dir,3.5),36,18,0.6,22,3);a.cooldown=0.075
		"stamp":
			melee(a,dir,3.2 if a.is_on_floor() else 4.6,200,1.6);a.cooldown=0.42;a.kit.guard=0.45
			for s in shots.duplicate():
				if s.team!=a.team and s.pos.distance_to(a.position)<3.2:_remove_shot(s)
		"kraken": melee(a,dir,2.3,200,1.15);a.velocity.y=8.5;a.cooldown=0.65
		"wail": beam(a,dir,72,26,1.5,true);a.cooldown=0.1
		"blower":
			if a.special_shots<3:
				emit_shot(a,dir,1.4,180,3.8,15,0,4.0,"bubble",{"life":9.0,"fuse":-1.0,"hp":55})
				a.special_shots+=1
				a.cooldown=1.5
		"booyah": pass

func step(dt: float):
	for s in shots.duplicate():
		s.age+=dt
		s.life-=dt
		var a=game.actors[int(s.owner)]
		if s.get("removed",false):continue
		if s.armed:
			s.fuse-=dt
			if s.fuse<=0: _detonate(s,a);_remove_shot(s)
			continue
		InkSubRunner.update(self,s,a,dt)
		if s.get("fuse_started",false):
			s.fuse-=dt
			if s.fuse<=0:_detonate(s,a);_remove_shot(s);continue
		if s.get("hp",1)<=0:_remove_shot(s);continue
		var old: Vector3=s.pos
		if s.age>float(s.get("straight",0)):
			s.vel.y-=float(s.gravity)*dt
			s.vel*=exp(-float(s.get("drag",0))*dt)
		if s.get("dive",false) and s.traveled>=s.reach:
			s.gravity=s.get("dive_gravity",140);s.drag=s.get("dive_drag",6)
		var next: Vector3=old+s.vel*dt
		var hit=game.ray(old,next,1)
		var direct=false
		var device_hit=blocking_device(old,next,int(s.team),float(s.damage))
		if not device_hit.is_empty() and (hit.is_empty() or old.distance_to(device_hit.position)<old.distance_to(hit.position)):
			next=device_hit.position;direct=true;s.pos=next
		for target_shot in shots:
			if target_shot==s or target_shot.kind=="bubble" or target_shot.team==s.team or not target_shot.has("hp"):continue
			if Geometry3D.get_closest_point_to_segment(target_shot.pos,old,next).distance_to(target_shot.pos)<.35:
				target_shot.hp-=s.damage
				if target_shot.hp<=0:target_shot.splash=0;target_shot.life=0
				direct=true;s.pos=target_shot.pos;next=s.pos;break
		if s.kind!="bubble":
			for bubble in shots:
				if bubble.kind!="bubble" or bubble.get("removed",false):continue
				if Geometry3D.get_closest_point_to_segment(bubble.pos,old,next).distance_to(bubble.pos)<1.5:
					bubble.hp-=s.damage if bubble.team==s.team else -s.damage*.6
					direct=true
					if bubble.hp<=0:explode(bubble.pos,game.actors[int(bubble.owner)],4.0,180,45);bubble.life=0
		for other in game.actors:
			if other.team==s.team or not other.alive() or other.index in s.hit_ids: continue
			var pt=Geometry3D.get_closest_point_to_segment(other.position+Vector3.UP*(0.3 if other.swim else 0.75),old,next)
			if pt.distance_to(other.position+Vector3.UP*(0.3 if other.swim else 0.75))<float(s.get("hit_radius",0.09))+0.38:
				if hit.is_empty() or old.distance_to(pt)<old.distance_to(hit.position):
					if InkSubRunner.contact(self,s,other):s.pos=pt;next=pt;break
					var dealt=float(s.damage)
					if float(s.get("falloff_end",0))>0:
						var t=clampf((float(s.traveled)-float(s.get("falloff_start",0)))/maxf(0.01,float(s.falloff_end)-float(s.get("falloff_start",0))),0,1)
						dealt=lerpf(dealt,float(s.get("falloff_damage",dealt)),t)
					var group=str(s.get("group",""))
					if group.is_empty() or not other.volley_hits.has(group):
						other.take_damage(dealt,a,false,old)
						if not group.is_empty():other.volley_hits[group]=other.age+3
					s.hit_ids.append(other.index);s.direct_id=other.index
					if s.kind=="tracer":other.marked=9
					s.pos=pt
					direct=true
					break
		if game.boss and game.boss.hp>0:
			var boss_hit=game.boss.segment_hit(old,next,0.1)
			if not boss_hit.is_empty() and (hit.is_empty() or boss_hit.distance<old.distance_to(hit.position)):
				game.boss.apply_segment_damage(boss_hit,float(s.damage),a)
				direct=true;s.pos=boss_hit.point
		if direct and not s.get("pierce",false):
			if s.kind=="arrow" and s.get("lodge",false):
				var floor_hit=game.ray(s.pos+Vector3.UP*0.1,s.pos-Vector3.UP*3,1)
				if not floor_hit.is_empty():s.pos=floor_hit.position+Vector3.UP*0.03
				s.armed=true
				if s.mesh:s.mesh.position=s.pos
				continue
			if s.splash>0:_detonate(s,a)
			_remove_shot(s)
			continue
		var distance=old.distance_to(next)
		s.traveled+=distance
		s.trail+=distance
		if float(s.get("trail_every",0))>0 and s.trail>=float(s.trail_every):
			s.trail=0;paint_ground(next,float(s.get("trail_radius",0.3)),a)
		s.pos=next
		if not hit.is_empty():
			s.pos=hit.position+hit.normal*0.03
			game.paint(hit.position,hit.normal,float(s.radius),a)
			if s.kind in ["curtain","sprinkler","scan","mist"]:
				deploy(s.kind,s.pos,a)
				_remove_shot(s)
				continue
			if s.kind in ["bomb","shaker","sticky"] or (s.kind=="arrow" and s.get("lodge",false)):
				if s.kind=="bomb" and s.bounces<2:
					s.vel=s.vel.bounce(hit.normal)*0.42
					s.bounces+=1
					s.fuse_started=true
				else:
					s.armed=true
					if s.mesh:s.mesh.position=s.pos
			elif s.kind=="tracer" and s.bounces<12:
				s.vel=s.vel.bounce(hit.normal)
				s.bounces+=1
			elif s.kind in ["seeker","waddle"]:
				if hit.normal.y>0.5:s.grounded=true;s.pos+=Vector3.UP*.1;s.vel.y=0
				else:s.vel=s.vel.bounce(hit.normal)
			elif s.kind=="boomerang":
				s.vel=Vector3.ZERO;s.state="hover";s.state_time=0
			else:
				if s.splash>0: _detonate(s,a)
				explosion_fx(s.pos,s.team,0.3)
				_remove_shot(s)
				continue
		if s.life<=0 or (s.traveled>=s.reach and not s.get("dive",false)) or s.pos.y < -2:
			if s.splash>0 and s.pos.y>=-1.5: _detonate(s,a)
			_remove_shot(s)
			continue
		if s.mesh: s.mesh.position=s.pos
	for g in gadgets.duplicate():
		g.life-=dt
		g.age+=dt
		g.tick-=dt
		var next_pos: Vector3=g.pos+g.vel*dt
		if g.kind=="canopy" and not game.ray(g.pos,next_pos+g.vel.normalized()*0.3,1).is_empty():g.vel=Vector3.ZERO
		g.pos=next_pos
		if g.kind=="curtain":g.hp-=19*dt
		if g.kind in ["curtain","canopy"]:
			for other in game.actors:
				if other.team==g.team or not other.alive():continue
				var offset: Vector3=other.position-g.pos
				var lateral=offset-Vector3(g.normal)*offset.dot(g.normal)
				if absf(offset.dot(g.normal))<0.5 and Vector2(lateral.x,lateral.z).length()<1.8 and absf(offset.y)<2.7:
					other.position+=Vector3(g.normal)*(0.5-absf(offset.dot(g.normal)))*signf(offset.dot(g.normal))
		var a=game.actors[int(g.owner)]
		if g.life<=0 or g.hp<=0 or (g.kind=="sprinkler" and not a.alive()):
			if g.kind=="slam": explode(g.pos,a,5.2,180,55)
			if g.mesh: g.mesh.queue_free()
			gadgets.erase(g)
			continue
		if g.mesh: g.mesh.position.x=g.pos.x;g.mesh.position.z=g.pos.z
		if g.tick>0: continue
		g.tick=0.25
		match g.kind:
			"canopy":paint_ground(g.pos,0.8,a)
			"sprinkler":
				g.tick=.3
				for i in 6:
					var angle=g.age*5+i*TAU/6
					var reach=lerpf(3.2,1.2,clampf(g.age/12,0,1))
					var p=g.pos+Vector3(cos(angle),0,sin(angle))*reach
					if game.ray(g.pos+Vector3.UP*.2,p+Vector3.UP*.2,1).is_empty():paint_ground(p,.65,a);_area_damage(p,a,.75,8)
			"storm":
				paint_ground(g.pos+Vector3(randf_range(-3,3),0,randf_range(-3,3)),1.0,a)
				_area_damage(g.pos,a,3.4,8.5)
			"strike":
				if g.age>2.2:
					paint_ground(g.pos,5.5,a)
					_area_damage(g.pos,a,5.5,15.5)
			"mine":
				if g.age>0.9:
					for other in game.actors:
						if other.team!=a.team and other.alive() and other.position.distance_to(g.pos)<2.1:
							if not g.has("triggered"):g.triggered=g.age+0.35
					if g.has("triggered") and g.age>=g.triggered:
						explode(g.pos,a,2.6,45,45)
						for other in game.actors:
							if other.team!=a.team and other.position.distance_to(g.pos)<2.6:other.marked=8
						g.life=0
			"mist", "scan":
				for other in game.actors:
					if other.team!=a.team and other.position.distance_to(g.pos)<3.5:
						if g.kind=="scan": other.marked=8
						else: other.slow=0.4;other.ink=maxf(0,other.ink-3)

func _detonate(s: Dictionary, a):
	var kind=s.kind
	if kind in ["scan","mist","curtain","sprinkler"]: deploy(kind,s.pos,a);return
	var def: Dictionary=game.catalog.SUBS.get(kind,{})
	explode(s.pos,a,float(s.splash),float(s.get("splash_damage",s.damage)),float(s.get("splash_min",def.get("damageMin",def.get("splashDamage",30)))),int(s.direct_id) if s.get("exclude_direct",false) else -1,float(s.get("inner",0)),float(s.get("paint_radius",def.get("paintRadius",s.splash))))
	if kind=="torpedo" and s.get("locked",false):
		var group=a.next_volley()
		for i in 10:
			var direction=Vector3(cos(i*TAU/10),.7,sin(i*TAU/10)).normalized()
			emit_shot(a,direction,6,12,.65,8,24,0,"ink",{"pos":s.pos,"group":group+str(i%3)})
	if kind=="shaker" and int(s.get("hops",0))<int(s.get("blasts",1))-1:
		emit_shot(a,Vector3.UP,0,float(s.damage),2.0,15,16,2.3,"shaker",{"pos":s.pos+Vector3.UP*0.2,"vel":a.forward()*4.2+Vector3.UP*4.6,"fuse":0.42,"hops":int(s.get("hops",0))+1,"blasts":s.get("blasts",1)})

func _area_damage(pos: Vector3,a,radius: float,damage: float):
	for other in game.actors:
		if other.team!=a.team and other.alive() and other.position.distance_to(pos)<radius: other.take_damage(damage,a)
	if game.boss and game.boss.position.distance_to(pos)<radius+2: game.boss.damage(damage,a)

func explode(pos: Vector3,a,radius: float,max_damage: float,min_damage: float,exclude_id: int=-1,inner: float=0,paint_radius: float=-1):
	if radius<=0:return
	for other in game.actors:
		if other.team==a.team or not other.alive(): continue
		var distance=other.position.distance_to(pos)
		if distance<radius and other.index!=exclude_id:
			if game.ray(pos+Vector3.UP*0.1,other.position+Vector3.UP*0.7,1).is_empty():
				other.take_damage(lerpf(max_damage,min_damage,clampf((distance-inner)/maxf(0.01,radius-inner),0,1)),a,false,pos)
	if game.boss and game.boss.position.distance_to(pos)<radius+3: game.boss.damage(max_damage,a)
	paint_ground(pos,paint_radius if paint_radius>=0 else radius,a)
	for i in 8:
		var dir=Vector3(cos(i*TAU/8),0.2,sin(i*TAU/8))
		var hit=game.ray(pos+Vector3.UP*0.1,pos+dir*radius,1)
		if not hit.is_empty(): game.paint(hit.position,hit.normal,radius*0.65,a)
	explosion_fx(pos,a.team,radius)
	game.sound.effect("boom",0.4)

func explosion_fx(pos: Vector3,team: int,radius: float):
	if game.online and game.authoritative:game.net_fx.rpc(pos,team,radius)
	if game.headless_test or effects.size()>100:return
	var n=InkContent.mesh(self,effect_mesh,pos,projectile_materials[team])
	n.scale=Vector3.ONE*maxf(0.03,radius*0.3)
	effects.append({"mesh":n,"life":0.35,"radius":radius})

func visual_step(dt: float):
	for e in effects.duplicate():
		e.life-=dt
		if e.life<=0:
			e.mesh.queue_free()
			effects.erase(e)
		else:
			e.mesh.scale=Vector3.ONE*e.radius*(0.2+e.life*1.6)

func _remove_shot(s):
	s.removed=true
	if s.mesh:s.mesh.queue_free()
	shots.erase(s)

func sync_remote(projectiles: Array,devices: Array):
	var visible_ids={}
	gadgets.clear()
	for g in devices:
		gadgets.append({"id":g[0],"kind":g[3],"pos":g[1],"team":g[2],"owner":g[4],"uses":g[5],"life":1.0})
	for item in projectiles+devices:
		var key=int(item[0])
		visible_ids[key]=true
		if not remote_visuals.has(key):
			var n=device_visual(item[3],int(item[2]),item[1])
			if not n.has_meta("source_device"):n.scale=Vector3.ONE*(1.5 if item[3]=="bubble" else 0.2)
			if item[3]=="curtain":n.scale=Vector3(1.7,1.4,0.12)
			remote_visuals[key]=n
		remote_visuals[key].position=item[1]
	for key in remote_visuals.keys():
		if not visible_ids.has(key):remote_visuals[key].queue_free();remote_visuals.erase(key)

func cheer(a):
	game.announce(a.nickname+" • YEAH!")
	for ally in game.actors:
		if ally.team==a.team and ally.special_time>0 and ally.special_id=="booyah":
			ally.special_tick+=float(game.catalog.SPECIALS.booyah.cheer)*float(game.catalog.SPECIALS.booyah.charge)
			if ally!=a:a.special=minf(a.weapon.specialCost,a.special+float(game.catalog.SPECIALS.booyah.cheerSpecial))
	game.sound.effect("booyah_cheer",0.5)

func device_visual(kind: String,team: int,pos: Vector3) -> Node3D:
	var path="res://assets/models/sub_"+kind+".glb"
	if ResourceLoader.exists(path):
		var node=load(path).instantiate();add_child(node);node.position=pos;node.scale=Vector3.ONE*2.8;node.set_meta("source_device",true)
		var painter=InkActor.new();painter.game=game;painter.team=team;painter._tint(node,{});painter.free()
		return node
	return InkContent.mesh(self,effect_mesh,pos,projectile_materials[team])

func launch_strike(a,point: Vector3):
	if a.special_time<=0 or a.special_id!="strike" or not a.kit.get("strike_aim",false):return
	if not point.is_finite():return
	var bounds: Dictionary=game.stage.bounds
	point.x=clampf(point.x,bounds.minX,bounds.maxX);point.z=clampf(point.z,bounds.minZ,bounds.maxZ)
	var floor_hit=game.ray(Vector3(point.x,30,point.z),Vector3(point.x,-2,point.z),1)
	if floor_hit.is_empty():return
	a.kit.strike_aim=false;a.special_time=6.7
	deploy("strike",floor_hit.position,a,{"life":6.7})
	game.sound.effect("strike_launch",0.7,a.position)

func blocking_device(start: Vector3,end: Vector3,team: int,damage: float) -> Dictionary:
	var nearest=INF;var result={};var target=null
	for g in gadgets:
		if g.team==team or g.life<=0 or g.hp<=0:continue
		var point: Vector3
		if g.kind in ["curtain","canopy"]:
			var normal: Vector3=g.normal
			var denominator=(end-start).dot(normal)
			if absf(denominator)<.0001:continue
			var t=(Vector3(g.pos)-start).dot(normal)/denominator
			if t<0 or t>1:continue
			point=start+(end-start)*t
			var offset: Vector3=point-g.pos
			var right=Vector3(normal.z,0,-normal.x)
			if absf(offset.dot(right))>float(g.width)/2 or offset.y<-.1 or offset.y>float(g.height):continue
		else:
			var center: Vector3=g.pos+Vector3.UP*.3
			point=Geometry3D.get_closest_point_to_segment(center,start,end)
			if point.distance_to(center)>.4:continue
		var distance=start.distance_to(point)
		if distance<nearest:nearest=distance;target=g;result={"position":point}
	if target:target.hp-=damage*(.5 if target.kind=="curtain" else 1.0)
	return result
