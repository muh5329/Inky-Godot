extends SceneTree

var game
var checks=0
var failures=0

func _initialize():call_deferred("run")

func check(condition: bool,message: String):
	checks+=1
	if not condition:failures+=1;push_error("TEST FAILED: "+message)
	else:print("PASS "+message)

func run():
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while game.state!="playing":await physics_frame
	game.set_physics_process(false)
	for a in game.actors:a.is_bot=false;a.commands={};a.protection=0
	var a=game.actors[0]
	var b=game.actors[1]
	var p=game.stage.turf_cells[100][2]
	game.stage.paint(p,Vector3.UP,1.2,0)
	check(game.stage.ink_at(p)==0,"surface queries see freshly painted own ink")
	var once=game.stage.paint(p,Vector3.UP,1.2,0)
	check(once==0,"repainting owned turf does not farm special charge")
	game.stage.paint(p,Vector3.UP,1.2,1)
	check(game.stage.ink_at(p)==1,"enemy paint replaces ownership")
	check(game.stage.totals[0]+game.stage.totals[1]<=game.stage.turf_total,"turf counts cannot exceed exposed surface area")
	var wall={}
	for f in game.stage.faces:
		if f.wall and f.paintable:wall=f;break
	var wallpos=wall.origin+wall.u*wall.su*0.5+wall.v*wall.sv*0.5
	game.stage.paint(wallpos,wall.n,1.2,0)
	check(game.stage.ink_at(wallpos,wall.n)==0,"wall paint is queryable for squid climbing")
	b.hp=100;b.protection=1;b.take_damage(80,a)
	check(b.hp==100,"spawn protection rejects incoming damage")
	b.protection=0;b.take_damage(150,a)
	check(b.respawn>0 and a.splats==1 and b.deaths==1,"splat awards attacker and starts respawn")
	b.step(6)
	check(b.alive() and b.hp==100 and b.ink==100,"respawn restores health and ink")
	for wid in game.catalog.WEAPON_ORDER:
		a.kit.clear();a.weapon_id=wid;a.weapon=game.catalog.WEAPONS[wid];a.cooldown=0;a.ink=100;a.charge=0;a.burst=0;a.special_time=0;a.previous_fire=false
		var before=game.combat.shots.size()
		game.combat.main_weapon(a,0.1,true,false)
		if wid in ["charger","bow","spinner","blade","mitts"]:
			a.charge=1;game.combat.main_weapon(a,0.1,false,true)
		check(a.ink<100,"weapon consumes ink: "+wid)
	# Values at the bow's ring boundaries are specified by the source bowShot function.
	var bow=game.catalog.WEAPONS.bow
	var tap=InkWeaponRunner.bow_shot(bow,0.44)
	var ring=InkWeaponRunner.bow_shot(bow,0.45)
	var full=InkWeaponRunner.bow_shot(bow,1)
	check(tap.tier==0 and tap.fuse<0,"bow tap never lodges or bursts")
	check(ring.tier==1 and ring.damage==30 and ring.fuse==0.7,"bow first ring uses source burst threshold")
	check(full.damage==55 and full.side==45 and full.speed==58,"bow full ring uses center/side damage and speed")
	a.weapon_id="brolly";a.weapon=game.catalog.WEAPONS.brolly;a.kit.clear();a.cooldown=0;a.ink=100;a.brolly_hold=0
	game.combat.main_weapon(a,0.01,true,false)
	check(is_equal_approx(a.ink,94.5),"brolly volley costs source 5.5 ink")
	game.combat.main_weapon(a,0.2,true,true)
	check(a.shield==450,"held canopy opens with 450 HP")
	a.hp=100;a.protection=0;a.yaw=0
	a.take_damage(36,b,false,a.position+Vector3(0,0,4))
	check(a.hp==100 and a.shield==414,"canopy blocks fire from its front")
	a.take_damage(36,b,false,a.position-Vector3(0,0,4))
	check(a.hp==64,"canopy leaves its owner's rear exposed")
	game.combat.main_weapon(a,0.8,true,true)
	check(a.shield==0 and a.kit.regrow>0 and game.combat.gadgets.back().kind=="canopy","continued brolly hold launches a regrowing canopy")
	a.weapon_id="mitts";a.weapon=game.catalog.WEAPONS.mitts;a.kit.clear();a.cooldown=0;a.ink=100;a.shield=0
	game.combat.main_weapon(a,0.1,true,false)
	check(game.combat.shots.back().kind=="fist" and is_equal_approx(a.ink,98.4),"mitts fire throws fists without charging")
	a.hp=100;a.protection=0
	a.take_damage(40,b,false,a.position+Vector3(0,0,4))
	check(a.hp==80,"raised mitts absorb half of frontal damage")
	a.sonar_time=8;a.ink=100
	InkWeaponRunner.spend(a,10)
	check(a.ink==86,"Deep Sonar increases ink consumption by 40 percent")
	a.sonar_time=0;a.hp=100;a.protection=0
	for sid in game.catalog.SUB_ORDER:
		a.sub_id=sid;a.ink=100;a.sub_cooldown=0
		var before=game.combat.shots.size()+game.combat.gadgets.size()
		game.combat.throw_sub(a)
		check(a.ink<100 and game.combat.shots.size()+game.combat.gadgets.size()>before,"sub creates projectile or deployable: "+sid)
	a.weapon_id="shooter";a.weapon=game.catalog.WEAPONS.shooter
	for sid in game.catalog.SPECIAL_ORDER:
		a.special_id=sid;a.special=float(a.weapon.specialCost);a.special_time=0;a.ink=10;a.cooldown=0
		game.combat.activate_special(a)
		check(a.special==0 and a.ink==100 and a.special_time>0,"special activates and refills tank: "+sid)
		game.combat.special_step(a,0.1)
		game.combat.main_weapon(a,0.1,true,false)
	a.special_time=0;a.shield=0
	for i in 180:game.combat.step(1.0/60)
	check(game.combat.shots.size()<100,"projectile lifecycle remains bounded")
	var zones=InkZones.new();game.world.add_child(zones);zones.setup(game)
	game.time_left=180
	for z in zones.objectives[0]:
		for cell in z.cells:game.stage.paint(cell[2],Vector3.UP,0.37,0)
	zones.step(0.3)
	check(zones.controller==0 and zones.counts[0]<100,"painted live zones capture and count down")
	zones.rotate_to(1)
	check(zones.active==1 and zones.controller==-1,"rotation resets objective control")
	var boss=InkBoss.new();game.world.add_child(boss);boss.setup(game)
	var before=boss.hp;boss.damage(100,a)
	check(boss.hp<before,"boss receives native weapon damage")
	boss.hp=boss.max_hp*0.2
	for move in game.catalog.BOSS_MOVES:
		boss.attack=move;boss.phase=3;boss.recovery=0;boss.windup=0
		boss.target_position=a.position;boss.charge_direction=Vector3.FORWARD
		boss.barrage_targets=[a.position,b.position]
		boss._begin_attack()
		check(boss.attack_duration>0,"boss attack starts: "+move)
		for i in 120:boss.step(1.0/60)
	check(boss.minions.size()>0,"phase-three brood creates crablets")
	game.combat.deploy("beacon",a.position,a)
	var beacon=game.combat.gadgets.back()
	a.hp=100;a.respawn=0;a.jump_time=0
	game._jump(a,-2-int(beacon.id))
	check(a.jump_time>0 and beacon.uses==1,"beacon super jump consumes a use")
	game.local_actor=a
	var level=game.profile.level
	game.finish_match(0,"TEST COMPLETE")
	check(game.state=="results" and game.result.xp>=1200 and game.profile.level>=level,"results award persistent progression")
	print("TEST_RESULT checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
