class_name InkLobby
extends SubViewportContainer
var game
var viewport: SubViewport
var scene: Node3D
var camera: Camera3D
var models: Array=[]
var clock=0.0
var camera_origin=Vector3.ZERO

func setup(owner_game,room: bool=false):
	game=owner_game
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stretch=true
	viewport=SubViewport.new();viewport.size=Vector2i(1440,900);viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d=Viewport.MSAA_2X;add_child(viewport)
	scene=Node3D.new();viewport.add_child(scene)
	var set=load("res://assets/models/lobby.glb").instantiate();scene.add_child(set)
	var library=InkStage.new();library.ink_material=ShaderMaterial.new();library.ink_material.shader=load("res://shaders/ink.gdshader");library._load_surface_library();library.free()
	var metadata: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/materials/manifest.json"))
	var slots=PackedVector4Array()
	for name in ["concrete","brick","render","concrete","metalpanel","corrugated","hazard","treads","planks","grate","rubber","asphalt"]:
		var m: Dictionary=metadata.meta[name];slots.append(Vector4(metadata.names.find(name),1.0/float(m.scale),2 if m.mask else (0 if m.tint==false else 1),0))
	for mesh in set.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var mat=mesh.get_active_material(surface)
			if mat.resource_name in ["LobbySurface","LobbyGround"]:
				var material=ShaderMaterial.new();material.shader=load("res://shaders/lobby.gdshader")
				for kind in InkStage.surface_arrays:material.set_shader_parameter("surface_"+kind,InkStage.surface_arrays[kind])
				material.set_shader_parameter("slots",slots);material.set_shader_parameter("decals",load("res://assets/lobby/decal.png"));material.set_shader_parameter("ground",mat.resource_name=="LobbyGround")
				mesh.set_surface_override_material(surface,material)
			elif mat.resource_name=="LobbyNeon":
				var material=ShaderMaterial.new();material.shader=load("res://shaders/neon.gdshader");mesh.set_surface_override_material(surface,material)
	var env=WorldEnvironment.new();var environment=Environment.new();env.environment=environment
	environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("172037")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color("9dabd4");environment.ambient_light_energy=.65
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	scene.add_child(env)
	var key=DirectionalLight3D.new();key.rotation_degrees=Vector3(-35,-35,0);key.light_color=Color("ffd2a6");key.light_energy=1.6;scene.add_child(key)
	var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/lobby.json"))
	var view: Dictionary=layout.camera if room else layout.hubCamera
	camera=Camera3D.new();scene.add_child(camera);camera.position=InkContent.vec(view.pos);camera.look_at(InkContent.vec(view.target));camera.fov=view.fov;camera.current=true;camera_origin=camera.position
	var profiles=game.peers.values() if room and game.online else [game.profile]
	for i in profiles.size():
		var profile: Dictionary=profiles[i]
		var look=InkActor.new();look.game=game;look.team=i%2
		var kid=load("res://assets/models/kid_%s.glb"%profile.get("weapon","shooter")).instantiate();scene.add_child(kid);look._tint(kid,profile)
		var spot: Dictionary=layout.spots[i] if room else layout.hubSpot
		kid.position=InkContent.vec(spot.pos);kid.rotation.y=spot.yaw
		var animation=look._find_anim(kid)
		if animation:
			for clip in animation.get_animation_list():
				if clip.ends_with("idle"):animation.get_animation(clip).loop_mode=Animation.LOOP_LINEAR;animation.play(clip);animation.seek(i*.2,true)
		models.append(kid);look.free()

func _process(dt: float):
	clock+=dt
	if camera:camera.position=camera_origin+Vector3(sin(clock*.16)*.035,sin(clock*.21)*.02,0)
