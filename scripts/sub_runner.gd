class_name InkSubRunner
extends RefCounted

static func nearest(c,s,radius: float):
	var target=null
	for other in c.game.actors:
		if other.team==s.team or not other.alive():continue
		var distance: float=other.position.distance_to(s.pos)
		if distance<radius and c.game.ray(s.pos,other.position+Vector3.UP*.6,1).is_empty():target=other;radius=distance
	return target

static func update(c,s,a,dt: float):
	if not s.kind in ["seeker","waddle","torpedo","boomerang"]:return
	var w: Dictionary=c.game.catalog.SUBS[s.kind]
	var state: String=s.get("state","fly")
	s.tick=float(s.get("tick",0))-dt
	if s.kind=="boomerang":
		s.gravity=0;s.reach=1000
		if not a.alive():s.life=0;return
		if state=="fly" and s.age>=w.outTime:s.state="hover";s.state_time=0;s.vel=Vector3.ZERO
		state=s.get("state","fly")
		s.state_time=float(s.get("state_time",0))+dt
		if state=="hover":
			if s.tick<=0:c._area_damage(s.pos,a,w.hoverRadius,w.tickDamage);c.paint_ground(s.pos,w.hoverPaint,a);s.tick=1.0/float(w.tickRate)
			if s.state_time>=w.hover:s.state="return";s.state_time=0
		elif state=="return":
			s.vel=(a.position+Vector3.UP*.7-s.pos).normalized()*float(w.returnSpeed)
			if s.pos.distance_to(a.position+Vector3.UP*.7)<1.5:s.state="orbit";s.state_time=0
		elif state=="orbit":
			s.vel=Vector3.ZERO
			s.pos=a.position+Vector3(cos(s.state_time*float(w.orbitSpin))*float(w.orbitRadius),.7,sin(s.state_time*float(w.orbitSpin))*float(w.orbitRadius))
			if s.tick<=0:c._area_damage(s.pos,a,.8,w.orbitDamage);c.paint_ground(s.pos,.5,a);s.tick=w.orbitHitCd
			if s.state_time>=w.orbit:s.life=0
		elif state=="attached":
			s.vel=Vector3.ZERO
			var victim=c.game.actors[int(s.victim)]
			s.pos=victim.position+Vector3.UP*.7
			if s.state_time>=w.hitFuse:s.splash=w.hitRadius;s.damage=w.hitDamageMax;s.splash_min=w.hitDamageMin;s.life=0
		return
	if s.kind=="torpedo":
		if not s.has("hp"):s.hp=w.hp
		if state=="fly" and s.age>=w.armTime:
			var target=nearest(c,s,w.lockRange)
			if target:
				s.target=target.index;s.state="unfold";s.state_time=0;s.vel=Vector3.ZERO;s.gravity=0
				c.game.sound.effect("torpedo_lock",.5,s.pos)
		elif state=="unfold":
			s.state_time=float(s.get("state_time",0))+dt
			if s.state_time>=w.unfoldTime:s.state="seek";s.speed=w.launchSpeed0;s.life=w.launchLife;s.locked=true
		elif state=="seek":
			var target=c.game.actors[int(s.target)]
			s.speed=minf(w.launchSpeed,float(s.get("speed",w.launchSpeed0))+float(w.launchAccel)*dt)
			var heading: Vector3=(target.position+Vector3.UP*.7-s.pos).normalized()
			var current: Vector3=s.vel.normalized() if s.vel.length()>.01 else heading
			s.vel=current.slerp(heading,minf(1,float(w.turnRate)*dt))*float(s.speed)
		return
	if not s.get("grounded",false):return
	s.gravity=0
	if s.kind=="waddle" and not s.has("hp"):s.hp=w.hp
	var radius=float(w.get("seekRange",w.get("senseRadius",7.5)))
	var target=nearest(c,s,radius)
	if target:
		var distance: float=target.position.distance_to(s.pos)
		if distance<float(w.triggerDist):s.armed=true;s.fuse=.15;s.vel=Vector3.ZERO;return
		var dir: Vector3=target.position-s.pos;dir.y=0;dir=dir.normalized()
		var heading: Vector3=s.vel.normalized() if s.vel.length()>.01 else dir
		if distance>float(w.get("commitDist",0)):heading=heading.slerp(dir,minf(1,float(w.turnRate)*dt))
		s.vel=heading*float(w.speed)
	else:
		if s.kind=="waddle":s.armed=true;s.vel=Vector3.ZERO;return
		s.vel=s.vel.normalized()*float(w.speed)*float(w.creep)
	var next: Vector3=s.pos+s.vel*dt
	var ground=c.game.ray(next+Vector3.UP*.7,next-Vector3.UP*1.2,1)
	if not ground.is_empty():s.pos.y=ground.position.y+.1
	else:s.grounded=false;s.gravity=24
	if s.kind=="seeker" and s.tick<=0:c.paint_ground(s.pos,w.trailRadius,a);s.tick=.08

static func contact(c,s,other) -> bool:
	if s.kind!="boomerang":return false
	if s.get("state","")=="attached":return true
	s.state="attached";s.state_time=0;s.victim=other.index;s.vel=Vector3.ZERO
	return true
