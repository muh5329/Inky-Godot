class_name InkCharacterRig
extends SkeletonModifier3D

var actor
var bones: Dictionary={}
var age=0.0
var previous_velocity=Vector3.ZERO
var spring=Vector2.ZERO
var spring_velocity=Vector2.ZERO
var blink_at=2.0
var blink=0.0

func configure(owner_actor,weapon: String):
	actor=owner_actor
	var names: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/rig_"+weapon+".json"))
	for key in names:bones[key]=get_skeleton().find_bone(names[key])

func rotate_bone(key: String,axis: Vector3,angle: float):
	var bone=int(bones.get(key,-1))
	if bone<0:return
	var skeleton=get_skeleton()
	skeleton.set_bone_pose_rotation(bone,skeleton.get_bone_pose_rotation(bone)*Quaternion(axis,angle))

func _process_modification_with_delta(delta: float):
	if not is_instance_valid(actor) or delta<=0:return
	var dt=minf(delta,0.05)
	age+=dt
	var skeleton=get_skeleton()
	# Aim is layered after the original exported animation, keeping both hands on the weapon.
	rotate_bone("spine",Vector3.RIGHT,-actor.pitch*.30)
	rotate_bone("chest",Vector3.RIGHT,-actor.pitch*.45)
	rotate_bone("neck",Vector3.RIGHT,-actor.pitch*.15)
	rotate_bone("head",Vector3.RIGHT,-actor.pitch*.10)
	var acceleration=(actor.velocity-previous_velocity)/maxf(dt,.001)
	previous_velocity=actor.velocity
	var local_accel=actor.body_model.global_basis.inverse()*acceleration
	var force=Vector2(clampf(local_accel.z*.002,-.25,.25),clampf(-local_accel.x*.002,-.25,.25))
	spring_velocity+=(force-spring*30-spring_velocity*8)*dt
	spring+=spring_velocity*dt
	for strand in 8:
		for joint in 3:
			var weight=(joint+1)/3.0
			rotate_bone("hair%d_%d"%[strand,joint],Vector3.RIGHT,spring.x*weight)
			rotate_bone("hair%d_%d"%[strand,joint],Vector3.FORWARD,spring.y*weight)
	if age>=blink_at:blink=.16;blink_at=age+randf_range(2.4,5.5)
	blink=maxf(0,blink-dt)
	for key in ["eyeL","eyeR"]:
		var id=int(bones.get(key,-1))
		if id>=0:
			var scale=skeleton.get_bone_pose_scale(id)
			scale.y*=lerpf(1,.08,sin((1-blink/.16)*PI)) if blink>0 else 1.0
			skeleton.set_bone_pose_scale(id,scale)
	rotate_bone("browL",Vector3.FORWARD,-.18 if actor.firing else 0)
	rotate_bone("browR",Vector3.FORWARD,.18 if actor.firing else 0)
	# Two-bone leg solve follows the collision surface, including sloped ramps.
	if actor.is_on_floor() and actor.velocity.length()<7 and not actor.swim:
		for side in ["L","R"]:_foot_ik(side)

func _foot_ik(side: String):
	var sk=get_skeleton()
	var hip=int(bones.get("thigh"+side,-1));var knee=int(bones.get("shin"+side,-1));var foot=int(bones.get("foot"+side,-1))
	if hip<0 or knee<0 or foot<0:return
	var h=sk.get_bone_global_pose(hip).origin
	var k=sk.get_bone_global_pose(knee).origin
	var f=sk.get_bone_global_pose(foot).origin
	var world=sk.global_transform*f
	var hit=actor.game.ray(world+Vector3.UP*.35,world-Vector3.UP*.45,1)
	if hit.is_empty():return
	var target=sk.global_transform.affine_inverse()*(hit.position+Vector3.UP*.075)
	var shift=clampf(target.y-f.y,-.22,.22)
	target=f+Vector3.UP*shift
	var l1=h.distance_to(k);var l2=k.distance_to(f)
	var distance=clampf(h.distance_to(target),.01,l1+l2-.001)
	var dir=(target-h).normalized()
	var bend=(k-h)-dir*(k-h).dot(dir)
	if bend.length()<.001:bend=Vector3.FORWARD-dir*Vector3.FORWARD.dot(dir)
	bend=bend.normalized()
	var along=(l1*l1+distance*distance-l2*l2)/(2*distance)
	var desired_knee=h+dir*along+bend*sqrt(maxf(0,l1*l1-along*along))
	_aim_segment(hip,k-h,desired_knee-h)
	k=sk.get_bone_global_pose(knee).origin
	f=sk.get_bone_global_pose(foot).origin
	_aim_segment(knee,f-k,target-k)

func _aim_segment(id: int,from: Vector3,to: Vector3):
	if from.length()<.001 or to.length()<.001:return
	var sk=get_skeleton()
	var parent=sk.get_bone_parent(id)
	var basis=sk.get_bone_global_pose(parent).basis if parent>=0 else Basis.IDENTITY
	var local_from=basis.inverse()*from.normalized()
	var local_to=basis.inverse()*to.normalized()
	sk.set_bone_pose_rotation(id,Quaternion(local_from.normalized(),local_to.normalized())*sk.get_bone_pose_rotation(id))
