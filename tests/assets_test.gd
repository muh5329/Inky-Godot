extends SceneTree
func _initialize():call_deferred("run")
func run():
	var checked=0
	var failed=0
	for file in DirAccess.get_files_at("res://assets/models"):
		if not file.ends_with(".glb"):continue
		var resource=load("res://assets/models/"+file)
		if not resource is PackedScene:failed+=1;push_error("Cannot load "+file);continue
		var scene=resource.instantiate()
		var meshes=scene.find_children("*","MeshInstance3D",true,false)
		if meshes.is_empty():failed+=1;push_error("No geometry in "+file)
		scene.free()
		checked+=1
		await process_frame
	print("ASSET_RESULT scenes=%d failures=%d" % [checked,failed])
	quit(1 if failed else 0)
