class_name InkAimAssist
extends RefCounted
var target_id=-1
var previous=Vector2.ZERO
var friction=1.0
var motion=Vector2.ZERO

func update(game,strength: float):
	friction=1.0;motion=Vector2.ZERO
	if strength<=0 or not game.camera or not game.local_actor:target_id=-1;return
	var a=game.local_actor
	var origin=game.camera.global_position
	var forward=-game.camera.global_basis.z
	var best=null;var closeness=0.0
	for enemy in game.actors:
		if enemy.team==a.team or not enemy.alive() or (enemy.submerged and enemy.marked<=0):continue
		var center=enemy.position+Vector3.UP*.75
		var offset=center-origin;var distance=offset.length()
		if distance<.5 or distance>35 or forward.dot(offset.normalized())<.99:continue
		if not game.ray(origin,center,1).is_empty():continue
		var angle=acos(clampf(forward.dot(offset.normalized()),-1,1))
		var window=atan2(.9,distance)+.025
		var value=1-clampf(angle/window,0,1)
		if value>closeness:closeness=value;best=enemy
	if not best:target_id=-1;return
	var offset: Vector3=best.position+Vector3.UP*.75-origin
	var angles=Vector2(atan2(offset.x,offset.z),atan2(offset.y,Vector2(offset.x,offset.z).length()))
	if target_id==best.index:motion=Vector2(angle_difference(previous.x,angles.x),angles.y-previous.y)*closeness*strength*.42
	target_id=best.index;previous=angles;friction=lerpf(1,.58,closeness*strength)
