class_name InkZones
extends Node3D

var game
var objectives: Array = []
var active = 0
var counts = [100.0,100.0]
var penalties = [0.0,0.0]
var controller = -1
var last_owner = -1
var stint_start = 100.0
var stint_starts=[100.0,100.0]
var tie_ends=[-1.0,-1.0]
var rotate_time = 45.0
var sample_time = 0.0
var overtime = false
var overtime_grace = 10.0
var overtime_loser = -1
var overtime_time = 0.0
var neutral_time = 0.0
var marker_root: Node3D

func setup(owner_game):
	game=owner_game
	var definitions: Dictionary=game.stage.data.zones
	if definitions.is_empty():
		definitions={"center":[{"poly":[[-5,-5],[5,-5],[5,5],[-5,5]],"y0":-2,"y1":6}],"side":{"poly":[[-5,-24],[5,-24],[5,-16],[-5,-16]],"y0":-2,"y1":6}}
	objectives.append(_objective(definitions.center,0))
	objectives.append(_objective([definitions.side],1))
	objectives.append(_objective([definitions.side],-1))
	_draw_markers()

func _objective(defs: Array, mirror: int) -> Array:
	var zones=[]
	for z in defs:
		var polys=[]
		for raw in z.get("polys",[z.get("poly",[])]):
			var p=PackedVector2Array()
			for v in raw:p.append(Vector2(v[0],v[1])*(-1 if mirror==-1 else 1))
			polys.append(p)
		var cells=[]
		var center=Vector3.ZERO
		for cell in game.stage.turf_cells:
			var pos: Vector3=cell[2]
			if pos.y<float(z.get("y0",-2)) or pos.y>float(z.get("y1",6)):continue
			for poly in polys:
				if Geometry2D.is_point_in_polygon(Vector2(pos.x,pos.z),poly):
					cells.append(cell)
					center+=pos
					break
		if cells.size()>0:center/=cells.size()
		zones.append({"cells":cells,"polys":polys,"center":center,"controller":-1,"shares":[0.0,0.0]})
	return zones

func _draw_markers():
	if marker_root:marker_root.queue_free()
	marker_root=Node3D.new()
	add_child(marker_root)
	if game.headless_test:return
	var mat=InkContent.material(Color("f4efac"),0.5)
	for z in objectives[active]:
		for poly in z.polys:
			for i in poly.size():
				var a=Vector3(poly[i].x,z.center.y+0.06,poly[i].y)
				var b=Vector3(poly[(i+1)%poly.size()].x,z.center.y+0.06,poly[(i+1)%poly.size()].y)
				var box=BoxMesh.new()
				box.size=Vector3(0.1,0.08,a.distance_to(b))
				var m=InkContent.mesh(marker_root,box,(a+b)*0.5,mat)
				if a.distance_to(b)>0.01:m.look_at(b)

func target_position() -> Vector3:
	return objectives[active][0].center if not objectives.is_empty() else Vector3.ZERO

func rotate_to(next: int):
	active=next
	controller=-1
	for z in objectives[active]:
		z.controller=-1
		for cell in z.cells:
			var f: Dictionary=game.stage.faces[cell[0]]
			var value=int(f.cells[cell[1]])
			if value in [1,2]:game.stage.totals[value-1]-=1
			f.cells[cell[1]]=0
			var uv: Vector3=cell[2]-f.origin
			var at: Dictionary=f.atlas
			var px=int(at.x+at.pad+uv.dot(f.u)*at.ppm)
			var py=int(at.y+at.pad+uv.dot(f.v)*at.ppm)
			game.stage.paint_image.fill_rect(Rect2i(px-2,py-2,5,5),Color(0,0,0,0))
	game.stage.dirty=true
	rotate_time=randf_range(35,55)
	if game.online and game.authoritative:game.net_zone_reset.rpc(active)
	_draw_markers()
	game.announce("ZONE ROTATED • "+["CENTRE","ALPHA SIDE","BRAVO SIDE"][active])

func step(dt: float):
	rotate_time-=dt
	if game.time_left<=30 and active!=0:rotate_to(0)
	elif rotate_time<=0 and game.time_left>40:rotate_to((active+1)%3)
	sample_time-=dt
	if sample_time<=0:
		sample_time=0.25
		var new_owner=-2
		for z in objectives[active]:
			var tally=[0,0]
			for cell in z.cells:
				var f: Dictionary=game.stage.faces[cell[0]]
				var value=int(f.cells[cell[1]])
				if value in [1,2]:tally[value-1]+=1
			z.shares=[float(tally[0])/maxi(1,z.cells.size()),float(tally[1])/maxi(1,z.cells.size())]
			if z.controller>=0 and z.shares[1-z.controller]>=0.4:z.controller=-1
			for team in 2:
				if z.shares[team]>=0.8 and z.controller!=team:
					z.controller=team
					for cell in z.cells:game.paint(cell[2],Vector3.UP,0.36,null,team)
			if new_owner==-2:new_owner=z.controller
			elif new_owner!=z.controller:new_owner=-1
		var old_controller=controller
		controller=maxi(-1,new_owner)
		if old_controller!=controller and controller==-1:neutral_time=0
		if controller>=0 and controller!=last_owner:
			if last_owner>=0:
				var end=maxf(tie_ends[last_owner],counts[last_owner]+penalties[last_owner])
				penalties[last_owner]+=roundf(maxf(0,stint_starts[last_owner]-end)*.75)+(1 if stint_starts[last_owner]==100 else 0)
			last_owner=controller
			stint_start=counts[controller]+penalties[controller]
			stint_starts[controller]=stint_start;tie_ends[controller]=-1
			game.announce("%s CONTROLS THE ZONE" % ["ALPHA","BRAVO"][controller])
	if controller>=0:
		var rate=1.0 if active==0 else (0.5 if active-1==controller else 2.0)
		var before=counts[controller]
		var from_penalty=minf(penalties[controller],dt*rate)
		penalties[controller]-=from_penalty
		counts[controller]=maxf(0,counts[controller]-(dt*rate-from_penalty))
		if tie_ends[controller]<0 and before>counts[1-controller] and counts[controller]<=counts[1-controller]:tie_ends[controller]=counts[1-controller]
		if counts[controller]<=0:game.finish_match(controller,"KNOCKOUT")
	if controller<0:neutral_time+=dt
	else:neutral_time=0
	var behind=-1 if is_equal_approx(counts[0],counts[1]) else (0 if counts[0]>counts[1] else 1)
	for a in game.actors:
		if a.special_time>0 or not a.alive():continue
		var rate=4.5 if controller>=0 and a.team!=controller else (1.5 if controller<0 and a.team==behind else 0)
		a.special=minf(float(a.weapon.specialCost),a.special+rate*dt)
	if game.time_left<=0:
		if not overtime:
			var grace=controller==-1 and last_owner==behind and neutral_time<10
			if behind<0 or controller==behind or grace:
				overtime=true;overtime_loser=behind;overtime_time=0
				game.announce("OVERTIME")
			else:game.finish_match(1-behind,"ZONE CONTROL");return
		overtime_time+=dt
		var losing=overtime_loser if overtime_loser>=0 else behind
		if losing<0:
			if overtime_time>=300:game.finish_match(0 if randf()<0.5 else 1,"OVERTIME")
			return
		var winning=1-losing
		if counts[losing]<counts[winning]:game.finish_match(losing,"COMEBACK")
		elif controller==winning or (controller!=losing and neutral_time>=10) or overtime_time>=300:game.finish_match(winning,"OVERTIME")

func contains_point(pos: Vector3) -> bool:
	for z in objectives[active]:
		if absf(pos.y-z.center.y)>3:continue
		for poly in z.polys:
			if Geometry2D.is_point_in_polygon(Vector2(pos.x,pos.z),poly):return true
	return false
