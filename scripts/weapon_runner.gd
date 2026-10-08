class_name InkWeaponRunner
extends RefCounted

# Source weapon timing is independent of presentation. All tuning comes from catalog.json.
static func spend(a, cost: float) -> bool:
	cost*=1.4 if a.sonar_time>0 else 1.0
	if a.ink+0.0001<cost:return false
	a.ink=maxf(0,a.ink-cost)
	a.fire_idle=0
	return true

static func bow_shot(w: Dictionary,c: float) -> Dictionary:
	if c>=0.999:
		return {"tier":2,"range":w.flightFull,"speed":w.speedFull,"damage":w.damageFull,"side":w.sideFull,"fan":w.fanFull,"fuse":w.fuseFull,"radius":w.burstRadius[1],"burst":w.burstDamage[1],"edge":w.burstEdge[1],"paint":w.burstPaint[1]}
	if c>=float(w.ring1):
		var u=(c-float(w.ring1))/(1-float(w.ring1))
		var d=lerpf(w.damageRing[0],w.damageRing[1],u)
		return {"tier":1,"range":lerpf(w.flightRing[0],w.flightRing[1],u),"speed":lerpf(w.speedRing[0],w.speedRing[1],u),"damage":d,"side":d*float(w.sideMul),"fan":w.fanRing,"fuse":w.fuseRing,"radius":w.burstRadius[0],"burst":w.burstDamage[0],"edge":w.burstEdge[0],"paint":w.burstPaint[0]}
	var u=clampf(c/float(w.ring1),0,1)
	var d=lerpf(w.damageTap[0],w.damageTap[1],u)
	return {"tier":0,"range":lerpf(w.flightTap[0],w.flightTap[1],u),"speed":w.speedTap,"damage":d,"side":d*float(w.sideMul),"fan":w.fanTap,"fuse":-1,"radius":0,"burst":0,"edge":0,"paint":w.paintTap}

static func update(c,a,dt: float,held: bool,was_held: bool):
	var w: Dictionary=a.weapon
	var k: Dictionary=a.kit
	var dir: Vector3=c.aim(a)
	var kind: String=a.weapon_id
	k.bloom=maxf(0,float(k.get("bloom",0))-dt/0.28) if not held else float(k.get("bloom",0))
	if kind=="brolly":
		_brolly(c,a,dt,held,was_held,dir)
		return
	if kind in ["charger","bow","spinner","splatling"]:
		if held and a.burst<=0 and a.cooldown<=0 and a.ink>float(w.get("inkFull",10))*0.15:
			k.charge_t=minf(1,float(k.get("charge_t",0))+dt/float(w.chargeTime))
			var t=float(k.charge_t)
			var curve=t*1.25 if t<0.2 else 0.25+(t-0.2)*0.9375
			a.charge=minf(a.ink/float(w.get("inkFull",24)),curve if kind=="charger" else t)
			a.fire_idle=0
		if not held and was_held and a.charge>0 and a.cooldown<=0:
			var charge=maxf(float(w.get("inkMin",0.12)),a.charge)
			a.charge=0;k.charge_t=0
			if kind in ["spinner","splatling"]:
				if kind=="spinner" and not spend(a,float(w.inkFull)*charge):return
				a.burst=lerpf(w.burstMin,w.burstMax,charge);k.power=charge
			elif kind=="charger":
				if not spend(a,float(w.inkFull)*charge):return
				var damage=float(w.damageMax) if charge>=0.999 else lerpf(w.damageMin,float(w.damageMax)*0.62,charge)
				c.beam(a,dir,lerpf(w.rangeMin,w.rangeMax,charge),damage,0.12,false,true)
				a.cooldown=0.28
			else:
				if not spend(a,float(w.inkFull)*charge):return
				var s=bow_shot(w,charge)
				var axis=Vector3.UP if a.is_on_floor() else dir.cross(Vector3.UP).normalized()
				for i in 3:
					c.emit_shot(a,dir.rotated(axis,deg_to_rad((i-1)*float(s.fan))),s.speed,s.damage if i==1 else s.side,w.paintTap,s.range,w.grav,s.radius,"arrow",{"fuse":s.fuse,"lodge":s.tier>0,"straight":w.straight,"dive":true,"dive_gravity":w.diveGrav,"dive_drag":w.diveDrag,"splash_damage":s.burst,"splash_min":s.edge,"paint_radius":s.paint,"inner":w.burstInner,"trail_every":w.trailEvery,"trail_radius":w.trailRadius})
				a.cooldown=w.cooldown
			c.game.sound.effect("bow_loose" if kind=="bow" else "shoot_charger",0.65)
		if a.burst>0:
			a.burst=maxf(0,a.burst-dt)
			if a.cooldown<=0:
				if kind=="splatling" and not spend(a,w.inkPerShot):a.burst=0;return
				var p=float(k.get("power",1))
				_round(c,a,dir,w,lerpf(w.get("speedMin",40),w.get("speedMax",40),p),lerpf(w.get("rangeMin",15),w.get("rangeMax",15),p),lerpf(w.get("straightMin",0.16),w.get("straightMax",0.16),p))
				a.cooldown=w.fireInterval;a.fire_idle=0
		return
	if kind=="blade":
		if held and not was_held and a.cooldown<=0:
			_blade_cut(c,a,dir,false)
			k.hold=0.0
		if held:
			k.hold=float(k.get("hold",0))+dt
			if k.hold>=float(w.chargeDelay):a.charge=minf(1 if a.ink>=w.heavyInk else 0.94,a.charge+dt/float(w.chargeTime));a.fire_idle=0
		elif was_held:
			if a.charge>=0.999:_blade_cut(c,a,dir,true)
			elif a.charge>=0.3 and a.cooldown<=0:_blade_cut(c,a,dir,false)
			a.charge=0;k.hold=0
		return
	if kind=="mitts":
		if a.mitts_charging or a.mitts_leaping:return
		if held and a.cooldown<=0 and spend(a,w.inkPerPunch):
			c.emit_shot(a,c.spread(dir,w.punchSpread),w.fistSpeed,w.punchDamage,w.fistPaint,w.fistRange,0,w.splashRadius,"fist",{"splash_damage":w.splashMax,"splash_min":w.splashMin,"exclude_direct":true})
			a.cooldown=w.punchInterval;k.guard=w.guardAfter
			c.game.sound.effect("mitts_punch",0.5)
		return
	if kind in ["roller","brush","bucket","slosher"]:
		_swing(c,a,dt,held,was_held,dir)
		return
	if not held or a.cooldown>0 or a.roll_time>0:return
	if not spend(a,w.inkPerShot):return
	if kind=="blaster":
		c.emit_shot(a,c.spread(dir,1.2 if a.is_on_floor() else 4),w.projSpeed,w.directDamage,w.impactRadius,w.range,0,w.splashRadius,"blaster",{"splash_damage":w.splashDamageMax,"splash_min":w.splashDamageMin,"paint_radius":w.burstRadius,"exclude_direct":true})
	else:
		var turret=kind=="twins" and a.turret_time>0
		_round(c,a,dir,w,w.get("turretProjSpeed",w.projSpeed) if turret else w.projSpeed,w.get("turretRange",w.range) if turret else w.range,w.get("turretStraight",w.straightTime) if turret else w.straightTime)
	a.cooldown=w.get("turretInterval",w.fireInterval) if a.turret_time>0 else w.fireInterval
	k.bloom=minf(1,float(k.bloom)+0.3)
	c.game.sound.effect("shoot_"+kind,0.45)

static func _round(c,a,dir,w,speed,reach,straight):
	var cone=float(w.spreadGround if a.is_on_floor() else w.spreadAir)
	if a.turret_time>0:cone=w.get("turretSpread",2.2)
	else:cone*=lerpf(0.45,1,float(a.kit.get("bloom",0)))
	c.emit_shot(a,c.spread(dir,cone),speed,w.damage,w.impactRadius,reach,28,0,"ink",{"straight":straight,"drag":0.8,"life":1.2,"trail_every":w.trailEvery,"trail_radius":w.trailRadius,"trail":-1.5})

static func _blade_cut(c,a,dir,heavy: bool):
	var w: Dictionary=a.weapon
	if not spend(a,w.heavyInk if heavy else w.tapInk):return
	c.melee(a,dir,w.reach,w.heavyMelee if heavy else w.tapMelee,w.strokeRadius)
	if heavy:
		c.emit_shot(a,dir,w.waveSpeed,w.waveDamage,w.waveEndRadius,w.waveRange,0,0,"wave",{"pierce":true,"hit_ids":[],"trail_every":w.wavePaintEvery,"trail_radius":w.wavePaintRadius,"falloff_end":w.waveRange,"falloff_damage":w.waveDamageFar,"hit_radius":w.waveWidth})
		a.roll_time=w.lungeTime;a.roll_velocity=Vector3(dir.x,0,dir.z).normalized()*float(w.lungeDist)/float(w.lungeTime)
	else:
		var volley=a.next_volley()
		for i in int(w.tapDrops):
			c.emit_shot(a,dir.rotated(Vector3.UP,deg_to_rad((float(i)/(w.tapDrops-1)-0.5)*float(w.tapSpreadDeg))),w.tapSpeed,w.tapDamageNear,w.tapDropRadius,w.range,24,0,"ink",{"straight":w.tapStraight,"falloff_end":w.range,"falloff_damage":w.tapDamageFar,"group":volley})
	a.cooldown=w.heavyInterval if heavy else w.tapInterval
	c.game.sound.effect("blade_heavy" if heavy else "blade_tap",0.6)

static func _swing(c,a,dt,held,was_held,dir):
	var w: Dictionary=a.weapon
	var k: Dictionary=a.kit
	var kind: String=a.weapon_id
	var bucket=kind in ["bucket","slosher"]
	var brush=kind=="brush"
	if float(k.get("windup",-1))>=0:
		k.windup-=dt
		if k.windup>0:return
		k.windup=-1
		var count=int(w.get("blobs",w.get("drops",w.get("flickDrops",5))))
		var volley=a.next_volley()
		for i in count:
			var angle=(float(i)/maxi(1,count-1)-0.5)*deg_to_rad(8 if bucket else float(w.flickSpreadDeg)*2)
			var d=(dir+Vector3.UP*(float(w.get("lob",0.3)) if bucket else 0)).normalized().rotated(Vector3.UP,angle)
			c.emit_shot(a,d,w.get("throwSpeed",w.get("projSpeed",w.get("flickSpeed",17))),w.get("damage",w.get("damageHead",w.get("flickDamageNear",125))),w.impactRadius,w.get("reach",w.get("range",12)),w.get("gravity",w.get("grav",24)),0,"ink",{"group":volley,"falloff_end":0 if bucket else 10,"falloff_damage":w.get("flickDamageFar",30),"drag":w.get("drag",0.8)})
		a.cooldown=float(w.get("fireInterval",w.get("flickInterval",0.62)))-float(w.get("windup",w.get("flickWindup",0.22)))
		c.game.sound.effect("shoot_bucket" if bucket else "roller_flick",0.6)
		return
	if (held and not was_held or bucket and held) and a.cooldown<=0:
		var cost=float(w.get("inkPerShot",w.get("flickInk",w.get("swipeInk",2.2))))
		if not spend(a,cost):return
		if brush:
			var volley=a.next_volley()
			for i in int(w.swipeDrops):c.emit_shot(a,dir.rotated(Vector3.UP,deg_to_rad((float(i)/(w.swipeDrops-1)-0.5)*float(w.swipeSpreadDeg)*2)),w.swipeSpeed,w.swipeDamageNear,w.impactRadius,7,24,0,"ink",{"group":volley,"falloff_end":7,"falloff_damage":w.swipeDamageFar})
			a.cooldown=w.swipeInterval
		else:k.windup=float(w.get("windup",w.get("flickWindup",0.12)))
	elif not bucket and held and was_held and a.is_on_floor() and a.cooldown<=0.25:
		var distance=Vector2(a.velocity.x,a.velocity.z).length()*dt
		if spend(a,distance*float(w.get("rollInkPerMeter",w.get("brushInkPerMeter",0.32)))):
			c.paint_ground(a.position+dir*0.55,float(w.get("rollWidth",w.get("brushWidth",0.95)))*0.5,a)
			if float(k.get("roll_hit",0))<=0:c.melee(a,dir,1.5,w.get("rollDamage",w.get("brushDamage",30)),0.5);k.roll_hit=w.get("brushHitCd",0.2)
	k.roll_hit=maxf(0,float(k.get("roll_hit",0))-dt)

static func _brolly(c,a,dt,held,was_held,dir):
	var w: Dictionary=a.weapon
	var k: Dictionary=a.kit
	k.regrow=maxf(0,float(k.get("regrow",0))-dt)
	k.canopy_hp=float(k.get("canopy_hp",w.canopyHp))
	if not held:
		a.brolly_hold=0;a.shield=0
		if a.fire_idle>w.canopyRegenDelay:k.canopy_hp=minf(w.canopyHp,k.canopy_hp+float(w.canopyRegen)*dt)
		return
	a.brolly_hold+=dt
	if float(k.regrow)<=0 and a.brolly_hold>=float(w.openDelay):
		a.shield=k.canopy_hp
		if a.brolly_hold>=float(w.launchHold):
			c.deploy("canopy",a.position+Vector3.UP+dir,a,{"vel":Vector3(dir.x,0,dir.z)*float(w.launchSpeed),"life":w.launchLife,"hp":a.shield,"normal":dir,"width":3.4,"height":2.7})
			k.regrow=w.regrowTime;a.shield=0;k.canopy_hp=w.canopyHp
	if not was_held and a.cooldown<=0 and spend(a,w.inkPerShot):
		for i in int(w.pellets):
			c.emit_shot(a,c.spread(dir,w.spreadDeg if a.is_on_floor() else w.spreadAir),w.projSpeed,w.pelletDamage,w.pelletPaint,w.range,w.pelletGrav,0,"ink",{"straight":w.straightTime,"drag":w.pelletDrag,"life":w.pelletLife,"falloff_start":w.falloffStart,"falloff_end":w.falloffEnd,"falloff_damage":w.pelletDamageFar})
		a.cooldown=w.fireInterval
		c.game.sound.effect("brolly_shoot",0.6)
