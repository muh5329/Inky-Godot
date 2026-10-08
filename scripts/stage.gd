class_name InkStage
extends Node3D

var data: Dictionary
var faces: Array = []
var face_hash: Dictionary = {}
var paint_image: Image
var paint_texture: ImageTexture
var ink_material: ShaderMaterial
var dirty = false
var upload_time = 0.0
var paint_clock = 0.0
var colors: Array
var navigation = AStar3D.new()
var nav_points: Array[Vector3] = []
var turf_cells: Array = []
var turf_total = 0
var totals = [0, 0]
var scores = [0.0, 0.0]
var bounds: Dictionary
var spawns: Array[Vector3] = []
var block_faces: Dictionary = {}
var block_hash: Dictionary = {}
var id = "tidewater"
var fast_test = false
static var surface_arrays: Dictionary = {}

func build(map_id: String, mode: String, team_colors: Array, dusk: bool = false, geometry: bool = true):
	id = map_id
	colors = team_colors
	var variant = "zones" if mode == "zones" else "turf"
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s_%s.json" % [id, variant]))
	bounds = data.bounds
	for p in data.spawnPads:
		spawns.append(InkContent.vec(p))
	paint_image = Image.create(int(data.atlasSize), int(data.atlasSize), false, Image.FORMAT_RGBA8)
	paint_image.fill(Color(0, 0, 0, 0))
	paint_texture = ImageTexture.create_from_image(paint_image)
	ink_material = ShaderMaterial.new()
	ink_material.shader = load("res://shaders/ink.gdshader")
	ink_material.set_shader_parameter("paint_atlas", paint_texture)
	ink_material.set_shader_parameter("team_a", colors[0])
	ink_material.set_shader_parameter("team_b", colors[1])
	if geometry:_load_surface_library()
	for fd in data.faces:
		var f: Dictionary = fd.duplicate(true)
		for key in ["origin", "n", "u", "v"]:
			f[key] = InkContent.vec(f[key])
		f.nu = maxi(1, ceili(float(f.su) * 2.0))
		f.nv = maxi(1, ceili(float(f.sv) * 2.0))
		f.cells = PackedByteArray()
		f.cells.resize(f.nu * f.nv)
		f.cells.fill(0)
		faces.append(f)
		if f.paintable:
			var c: Vector3 = f.origin + f.u * f.su * 0.5 + f.v * f.sv * 0.5
			var ext: Vector3 = f.u.abs() * f.su * 0.5 + f.v.abs() * f.sv * 0.5 + Vector3.ONE * 0.1
			for xx in range(floori((c.x-ext.x)/4), floori((c.x+ext.x)/4)+1):
				for zz in range(floori((c.z-ext.z)/4), floori((c.z+ext.z)/4)+1):
					var key = Vector2i(xx,zz)
					if not face_hash.has(key): face_hash[key] = []
					face_hash[key].append(int(f.id))
	for b in data.blocks:
		b.center = InkContent.vec(b.center)
		b.half = InkContent.vec(b.half)
		b.axes = [InkContent.vec(b.axes[0]),InkContent.vec(b.axes[1]),InkContent.vec(b.axes[2])]
		var ext: Vector3=b.axes[0].abs()*b.half.x+b.axes[1].abs()*b.half.y+b.axes[2].abs()*b.half.z
		for xx in range(floori((b.center.x-ext.x)/4),floori((b.center.x+ext.x)/4)+1):
			for zz in range(floori((b.center.z-ext.z)/4),floori((b.center.z+ext.z)/4)+1):
				var key=Vector2i(xx,zz)
				if not block_hash.has(key):block_hash[key]=[]
				block_hash[key].append(b)
		if not b.solid: continue
		var body = StaticBody3D.new()
		body.collision_layer = 4 if b.grate else 1
		body.collision_mask = 0
		body.set_meta("block", int(b.id))
		var shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = b.half * 2
		shape.shape = box
		body.add_child(shape)
		body.transform = Transform3D(Basis(b.axes[0], b.axes[1], b.axes[2]), b.center)
		add_child(body)
		if geometry and b.grate and not b.rail:
			var mesh=BoxMesh.new();mesh.size=b.half*2
			var mat=ShaderMaterial.new();mat.shader=load("res://shaders/grate.gdshader");mat.set_shader_parameter("dimensions",Vector2(mesh.size.x,mesh.size.z))
			var grate=InkContent.mesh(self,mesh,b.center,mat);grate.basis=Basis(b.axes[0],b.axes[1],b.axes[2])
	if geometry:
		var level = load("res://assets/models/%s_%s_level.glb" % [id,variant]).instantiate()
		add_child(level)
		_apply_ink(level)
		var props = load("res://assets/models/%s_%s_props.glb" % [id,variant]).instantiate()
		add_child(props)
		_prepare_props(props)
		_environment(dusk)
	_build_nav()
	# Only exposed cells count as turf; buried portions of intersecting boxes are excluded.
	for f in faces:
		if not f.turf or not f.paintable: continue
		for j in f.nv:
			for i in f.nu:
				var pos: Vector3 = f.origin + f.u * ((i+0.5)*f.su/f.nu) + f.v * ((j+0.5)*f.sv/f.nv)
				if _inside_block(pos + f.n * 0.06, int(f.block)):
					f.cells[j*f.nu+i] = 255
				else:
					turf_cells.append([int(f.id), j*f.nu+i, pos])
					turf_total += 1

func _inside_block(pos: Vector3, skip: int) -> bool:
	for b in block_hash.get(Vector2i(floori(pos.x/4),floori(pos.z/4)),[]):
		if int(b.id) == skip or not b.solid: continue
		var d = pos - b.center
		var h: Vector3 = b.half
		if absf(d.dot(b.axes[0])) < h.x and absf(d.dot(b.axes[1])) < h.y and absf(d.dot(b.axes[2])) < h.z:
			return true
	return false

func _load_surface_library():
	var path="res://assets/materials/manifest.json"
	if not FileAccess.file_exists(path):return
	var lib: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	if surface_arrays.is_empty():
		for kind in ["albedo","normal","orm"]:
			var images: Array[Image]=[]
			for material_name in lib.names:
				var texture: Texture2D=load("res://assets/materials/%s_%s.png" % [str(material_name).replace(":","_"),kind])
				var img=texture.get_image()
				img.convert(Image.FORMAT_RGBA8);img.generate_mipmaps();images.append(img)
			var array=Texture2DArray.new();array.create_from_images(images);surface_arrays[kind]=array
	for kind in surface_arrays:ink_material.set_shader_parameter("surface_"+kind,surface_arrays[kind])
	var slots=PackedVector4Array();var remap=PackedVector4Array()
	for i in 64:
		var name=str(lib.slots[mini(i,lib.slots.size()-1)])
		var meta: Dictionary=lib.meta[name]
		slots.append(Vector4(lib.names.find(name),1.0/float(meta.scale),2 if meta.mask else (0 if meta.tint==false else 1),float(meta.detail)))
		remap.append(Vector4(int(lib.onWall.get(str(i),i)),int(lib.onTop.get(str(i),i)),0,0))
	ink_material.set_shader_parameter("surface_slots",slots)
	ink_material.set_shader_parameter("surface_remap",remap)
	ink_material.set_shader_parameter("use_surface_library",true)

func _apply_ink(n: Node):
	if n is MeshInstance3D: n.material_override = ink_material
	for child in n.get_children(): _apply_ink(child)

func _prepare_props(n: Node):
	if n is MeshInstance3D:
		for i in n.mesh.get_surface_count():
			var mat=n.get_active_material(i)
			if mat is StandardMaterial3D:
				mat=mat.duplicate()
				var arrays=n.mesh.surface_get_arrays(i)
				mat.vertex_color_use_as_albedo=arrays[Mesh.ARRAY_COLOR]!=null and arrays[Mesh.ARRAY_COLOR].size()>0
				mat.vertex_color_is_srgb=false
				n.set_surface_override_material(i,mat)
	for child in n.get_children():_prepare_props(child)

func _environment(dusk: bool):
	var env = WorldEnvironment.new()
	var e = Environment.new()
	var sky = Sky.new()
	var sm = ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("394970") if dusk else Color("408cc0")
	sm.sky_horizon_color = Color("f0aa87") if dusk else Color("bddfdf")
	sm.ground_horizon_color = sm.sky_horizon_color
	sm.ground_bottom_color = Color("557577")
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("bac6e7") if dusk else Color("c6dce7")
	e.ambient_light_energy = 0.22
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.85
	env.environment = e
	add_child(env)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-25 if dusk else -48,-32,0)
	sun.light_color = Color("ffbc8e") if dusk else Color("fff1dc")
	sun.light_energy = 0.65
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90
	add_child(sun)
	var plane = PlaneMesh.new()
	plane.size = Vector2(800,800)
	plane.subdivide_width = 80
	plane.subdivide_depth = 80
	var water = ShaderMaterial.new()
	water.shader = load("res://shaders/water.gdshader")
	InkContent.mesh(self,plane,Vector3(0,-1.65,0),water)
	for team in 2:
		var pad = CylinderMesh.new()
		pad.top_radius = 2.2
		pad.bottom_radius = 2.2
		pad.height = 0.04
		InkContent.mesh(self,pad,spawns[team]+Vector3.UP*0.025,InkContent.material(colors[team],0.3))

func _build_nav():
	for p in data.nav:
		var pos = Vector3(p[1],p[2]+0.1,p[3])
		navigation.add_point(int(p[0]),pos)
		nav_points.append(pos)
	var width = int(data.navWidth)
	for p in data.nav:
		var a = int(p[0])
		for offset in [1,width,width+1,width-1]:
			var b = a + offset
			if not navigation.has_point(b): continue
			var pa = navigation.get_point_position(a)
			var pb = navigation.get_point_position(b)
			if pa.distance_to(pb) < 2.7 and absf(pa.y-pb.y) < 1.25 and _nav_clear(pa+Vector3.UP*0.8,pb+Vector3.UP*0.8):
				navigation.connect_points(a,b)

func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	if navigation.get_point_count()==0: return PackedVector3Array()
	return navigation.get_point_path(navigation.get_closest_point(from),navigation.get_closest_point(to),true)

func _process(dt: float):
	paint_clock+=dt
	if ink_material:ink_material.set_shader_parameter("paint_time",paint_clock)
	upload_time -= dt
	if dirty and upload_time <= 0:
		paint_texture.update(paint_image)
		dirty = false
		upload_time = 0.08

func candidates(pos: Vector3, radius: float = 0.0) -> Array:
	var found: Dictionary = {}
	for x in range(floori((pos.x-radius)/4),floori((pos.x+radius)/4)+1):
		for z in range(floori((pos.z-radius)/4),floori((pos.z+radius)/4)+1):
			for idx in face_hash.get(Vector2i(x,z),[]): found[idx]=true
	return found.keys()

func surface_at(pos: Vector3, normal: Vector3 = Vector3.UP) -> Dictionary:
	var best = 0.55
	var result: Dictionary = {}
	for idx in candidates(pos):
		var f: Dictionary = faces[idx]
		if f.n.dot(normal)<0.65: continue
		var d: Vector3 = pos-f.origin
		var depth = absf(d.dot(f.n))
		var uv = Vector2(d.dot(f.u),d.dot(f.v))
		if depth<best and uv.x>=0 and uv.y>=0 and uv.x<f.su and uv.y<f.sv:
			best=depth
			result={"face":idx,"uv":uv}
	return result

func ink_at(pos: Vector3, normal: Vector3 = Vector3.UP) -> int:
	var s=surface_at(pos,normal)
	if s.is_empty(): return -1
	var f: Dictionary=faces[s.face]
	var ix=clampi(int(s.uv.x/f.su*f.nu),0,f.nu-1)
	var iy=clampi(int(s.uv.y/f.sv*f.nv),0,f.nv-1)
	var value=int(f.cells[iy*f.nu+ix])
	return value-1 if value in [1,2] else -1

func paint(pos: Vector3, normal: Vector3, radius: float, team: int) -> float:
	var gained = 0.0
	for idx in candidates(pos,radius):
		var f: Dictionary=faces[idx]
		if not f.paintable or f.atlas==null or f.n.dot(normal)<0.45: continue
		var d: Vector3=pos-f.origin
		if absf(d.dot(f.n)) > 0.4: continue
		var u=d.dot(f.u)
		var v=d.dot(f.v)
		var rr=radius*radius
		var x0=clampi(floori((u-radius)/f.su*f.nu),0,f.nu-1)
		var x1=clampi(ceili((u+radius)/f.su*f.nu),0,f.nu-1)
		var y0=clampi(floori((v-radius)/f.sv*f.nv),0,f.nv-1)
		var y1=clampi(ceili((v+radius)/f.sv*f.nv),0,f.nv-1)
		for yy in range(y0,y1+1):
			for xx in range(x0,x1+1):
				if Vector2((xx+0.5)*f.su/f.nu-u,(yy+0.5)*f.sv/f.nv-v).length_squared()>rr: continue
				var k=yy*f.nu+xx
				var old=int(f.cells[k])
				if old==255 or old==team+1: continue
				f.cells[k]=team+1
				if f.turf:
					if old>0: totals[old-1]-=1
					totals[team]+=1
					gained += f.su*f.sv/(f.nu*f.nv)
		var a: Dictionary=f.atlas
		var ppm=float(a.ppm)
		var col=Color(float(team),fmod(paint_clock,255.0)/255.0,0,1)
		for yy in range(maxi(0,floori((v-radius)*ppm)),mini(ceili(f.sv*ppm),ceili((v+radius)*ppm))+1):
			for xx in range(maxi(0,floori((u-radius)*ppm)),mini(ceili(f.su*ppm),ceili((u+radius)*ppm))+1):
				var delta=Vector2(xx/ppm-u,yy/ppm-v)
				var edge=1.0+0.06*sin(atan2(delta.y,delta.x)*7.0+u*2.0)
				if delta.length_squared()<rr*edge:
					paint_image.set_pixel(int(a.x+a.pad)+xx,int(a.y+a.pad)+yy,col)
		dirty=true
	return gained

func coverage() -> Array:
	return [100.0*totals[0]/maxi(1,turf_total),100.0*totals[1]/maxi(1,turf_total)]

func _nav_clear(start: Vector3,end: Vector3) -> bool:
	var checked={}
	for x in range(floori(minf(start.x,end.x)/4),floori(maxf(start.x,end.x)/4)+1):
		for z in range(floori(minf(start.z,end.z)/4),floori(maxf(start.z,end.z)/4)+1):
			for b in block_hash.get(Vector2i(x,z),[]):
				if checked.has(b.id) or not b.solid or b.grate:continue
				checked[b.id]=true
				var offset=start-b.center;var delta=end-start
				var lo=0.0;var hi=1.0
				for axis in 3:
					var p: float=offset.dot(b.axes[axis]);var d: float=delta.dot(b.axes[axis]);var h=float(b.half[axis])+0.18
					if absf(d)<.00001:
						if absf(p)>h:lo=2;break
					else:
						var t0=(-h-p)/d;var t1=(h-p)/d
						lo=maxf(lo,minf(t0,t1));hi=minf(hi,maxf(t0,t1))
				if lo<=hi:return false
	return true
