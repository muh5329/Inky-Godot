class_name InkHUD
extends CanvasLayer

var game
var root: Control
var page: Control
var overlay: Control
var drawing: Control
var clock_label: Label
var score_label: Label
var info_label: Label
var banner_label: Label
var ink_bar: ProgressBar
var hp_bar: ProgressBar
var special_bar: ProgressBar
var prompt_label: Label
var map_view: TextureRect
var map_image: Image
var map_texture: ImageTexture
var map_timer = 0.0
var map_expanded = false
var hit_flash = 0.0
var screen = "main"
var current_poster: TextureRect
var connection_label: Label
var banner_time = 0.0
var notice = ""
var font: Font
var display_font: Font
var orange = Color("ff942e")
var navy = Color("152535")
var cream = Color("fff8e8")
var choices: Dictionary = {}
var translated: Dictionary = {}

func setup(owner_game):
	game=owner_game
	root=Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	font=load("res://assets/fonts/body.ttf")
	display_font=load("res://assets/fonts/display.ttf")
	var chinese=load("res://assets/fonts/chinese.ttf")
	font=font.duplicate();display_font=display_font.duplicate()
	font.fallbacks=[chinese];display_font.fallbacks=[chinese]
	for phrase in game.catalog.ZH_PHRASES:translated[str(phrase).to_lower()]=game.catalog.ZH_PHRASES[phrase]
	translated.merge(JSON.parse_string(FileAccess.get_file_as_string("res://data/native_zh.json")),true)
	var theme=Theme.new()
	theme.default_font=font
	theme.default_font_size=19
	for state_name in ["normal","hover","pressed","focus"]:
		var s=StyleBoxFlat.new()
		s.bg_color=Color("284354") if state_name=="normal" else Color("436174")
		s.corner_radius_top_left=8
		s.corner_radius_bottom_right=8
		s.content_margin_left=18
		s.content_margin_right=18
		s.content_margin_top=12
		s.content_margin_bottom=12
		if state_name=="focus":s.set_border_width_all(2);s.border_color=orange
		theme.set_stylebox(state_name,"Button",s)
		theme.set_stylebox(state_name,"OptionButton",s)
	theme.set_color("font_color","Label",cream)
	theme.set_color("font_color","Button",cream)
	root.theme=theme
	show_menu("main")

func t(value: String) -> String:
	return str(translated.get(value.to_lower(),value)) if game.settings.lang=="zh" else value

func label(parent: Node,text: String,size: int=20,color: Color=Color("fff8e8"),display: bool=false) -> Label:
	var l=Label.new()
	l.text=t(text)
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",color)
	if parent==overlay:
		l.add_theme_color_override("font_shadow_color",Color(0.02,0.06,0.08,0.9));l.add_theme_constant_override("shadow_offset_x",1);l.add_theme_constant_override("shadow_offset_y",2)
	if display:l.add_theme_font_override("font",display_font)
	parent.add_child(l)
	return l

func button(parent: Node,text: String,action: Callable,primary: bool=false) -> Button:
	var b=Button.new()
	b.text=t(text)
	b.alignment=HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.y=50
	if primary:
		var s=StyleBoxFlat.new()
		s.bg_color=orange
		s.set_corner_radius_all(8)
		s.content_margin_left=20
		b.add_theme_stylebox_override("normal",s)
		b.add_theme_color_override("font_color",navy)
		b.add_theme_font_override("font",display_font)
	b.pressed.connect(func():game.sound.effect("ui");action.call())
	parent.add_child(b)
	if primary:b.call_deferred("grab_focus")
	return b

func show_menu(which: String):
	screen=which
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if page:page.queue_free()
	if overlay:overlay.visible=false
	page=Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(page)
	if which in ["main","online"] and not game.headless_test:
		var lobby=InkLobby.new();page.add_child(lobby);lobby.setup(game,which=="online")
	elif which not in ["pause","results"]:
		var background=TextureRect.new()
		background.texture=load("res://assets/stages/%s-%s.webp" % [game.options.map,game.options.time])
		background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		page.add_child(background)
		current_poster=background
	var dim=ColorRect.new()
	dim.color=Color(0.025,0.065,0.1,0.25 if which=="main" else 0.68)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(dim)
	var panel=Panel.new()
	panel.position=Vector2(40,36)
	panel.size=Vector2(535,828)
	var style=StyleBoxFlat.new()
	style.bg_color=Color(0.04,0.10,0.15,0.94)
	style.set_corner_radius_all(18)
	panel.add_theme_stylebox_override("panel",style)
	page.add_child(panel)
	var margin=MarginContainer.new()
	margin.position=Vector2(70,60)
	margin.size=Vector2(475,770)
	page.add_child(margin)
	var scroll=ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var box=VBoxContainer.new()
	box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",12)
	scroll.add_child(box)
	label(box,"INKWAVE",63,orange,true)
	label(box,"T U R F   R I O T",17,cream)
	var line=HSeparator.new();box.add_child(line)
	match which:
		"main":_main(box)
		"setup":_setup_menu(box)
		"loadout":_loadout(box)
		"locker":_locker(box)
		"settings":_settings(box)
		"controls":_controls(box)
		"online":_online(box)
		"pause":
			label(box,"TAKE A BREATHER",27,cream,true)
			button(box,"RESUME",game.resume_match,true)
			button(box,"CONTROLS",func():show_menu("controls"))
			button(box,"LEAVE MATCH",game.return_to_menu)
		"results":_results(box)
	var footer=label(page,"NATIVE GODOT EDITION  /  ORIGINAL GAME BY JAYDEN DAVIS",13,cream)
	footer.position=Vector2(625,845)
	if which=="main":
		var tagline=label(page,"MAKE YOUR MARK.",31,cream,true)
		tagline.position=Vector2(645,760)
		var stage_name=label(page,game.map_name(game.options.map).to_upper(),19,cream,true)
		stage_name.position=Vector2(625,45)
	if which not in ["main","pause","results"]:
		button(box,"← BACK",func():show_menu("pause" if game.state=="playing" else "main"))

func _main(box):
	label(box,"Paint the city. Own the tide.",21)
	label(box,t("%s  /  LEVEL %d  /  %d XP") % [game.profile.name,game.profile.level,game.profile.xp],15,Color("9db8c3"))
	button(box,"PLAY  →",func():show_menu("setup"),true)
	button(box,"LOADOUT",func():show_menu("loadout"))
	button(box,"LOCKER",func():show_menu("locker"))
	button(box,"MULTIPLAYER",func():show_menu("online"))
	button(box,"SETTINGS",func():show_menu("settings"))
	button(box,"HOW TO PLAY",func():show_menu("controls"))
	button(box,"QUIT",game.quit_game)

func option(parent: Node,caption: String,values: Array,selected: int,callback: Callable) -> OptionButton:
	label(parent,caption.to_upper(),13,Color("9db8c3"))
	var o=OptionButton.new()
	for v in values:o.add_item(t(str(v)))
	o.selected=clampi(selected,0,values.size()-1)
	o.item_selected.connect(callback)
	parent.add_child(o)
	return o

func _setup_menu(box):
	label(box,"PICK YOUR BATTLE",26,cream,true)
	var maps=game.catalog.MAPS.filter(func(m):return not m.get("onlineOnly",false) or game.online)
	var names=maps.map(func(m):return m.name)
	var selected=0
	for i in maps.size():
		if maps[i].id==game.options.map:selected=i
	option(box,"Stage",names,selected,func(i):game.options.map=maps[i].id;show_menu("setup"))
	option(box,"Mode",["Turf War","Zone Control","Boss Battle"],["turf","zones","boss"].find(game.options.mode),func(i):game.options.mode=["turf","zones","boss"][i];game.options.duration=[180,300,240][i])
	option(box,"Time of day",["Day","Dusk"],0 if game.options.time=="day" else 1,func(i):game.options.time="day" if i==0 else "dusk";show_menu("setup"))
	option(box,"Bots",["Easy","Normal","Hard"],game.difficulty,func(i):game.difficulty=i)
	option(box,"Match length",["90 seconds","3 minutes","4 minutes","5 minutes"],[90,180,240,300].find(int(game.options.duration)),func(i):game.options.duration=[90,180,240,300][i])
	var w=game.catalog.WEAPONS[game.profile.weapon]
	label(box,"%s\n%s  +  %s" % [w.name,game.catalog.SUBS[game.profile.sub].name,game.catalog.SPECIALS[game.profile.special].name],17)
	button(box,"CHANGE LOADOUT",func():show_menu("loadout"))
	button(box,"LET’S MAKE WAVES  →",func():game.start_match(),true)

func _loadout(box):
	label(box,"YOUR ARSENAL",27,cream,true)
	var ids: Array=game.catalog.WEAPON_ORDER
	option(box,"Main weapon",ids.map(func(id):return game.catalog.WEAPONS[id].name),ids.find(game.profile.weapon),func(i):game.profile.weapon=ids[i];game.profile.sub=game.catalog.WEAPONS[ids[i]].sub;game.profile.special=game.catalog.WEAPONS[ids[i]].special;game.save_profile();show_menu("loadout"))
	var def: Dictionary=game.catalog.WEAPONS[game.profile.weapon]
	var desc=label(box,def.blurb,17)
	desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for stat in def.stats:
		label(box,str(stat).to_upper(),12,Color("9db8c3"))
		var bar=ProgressBar.new();bar.value=float(def.stats[stat])*100;bar.show_percentage=false;bar.custom_minimum_size.y=8;box.add_child(bar)
	var subs: Array=game.catalog.SUB_ORDER
	option(box,"Sub weapon",subs.map(func(id):return game.catalog.SUBS[id].name),subs.find(game.profile.sub),func(i):game.profile.sub=subs[i];game.save_profile();show_menu("loadout"))
	var specials: Array=game.catalog.SPECIAL_ORDER
	option(box,"Special",specials.map(func(id):return game.catalog.SPECIALS[id].name),specials.find(game.profile.special),func(i):game.profile.special=specials[i];game.save_profile();show_menu("loadout"))
	var subdesc=label(box,game.catalog.SUBS[game.profile.sub].blurb,15,Color("9db8c3"));subdesc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	button(box,"EQUIPPED  ✓",func():
		if game.online:game.lobby_choice(int(game.peers.get(game.multiplayer.get_unique_id(),{}).get("room_team",-1)),false)
		show_menu("online" if game.online else "setup"),true)
	_preview()

func _preview():
	var container=SubViewportContainer.new()
	container.position=Vector2(645,120)
	container.size=Vector2(700,660)
	container.stretch=true
	page.add_child(container)
	var viewport=SubViewport.new()
	viewport.size=Vector2i(700,660)
	viewport.transparent_bg=true
	viewport.own_world_3d=true
	container.add_child(viewport)
	var model=load("res://assets/models/kid_%s.glb" % game.profile.weapon).instantiate()
	var painter=InkActor.new();painter.game=game;painter.team=0;painter._tint(model,game.profile)
	var animation=painter._find_anim(model)
	if animation:
		for key in animation.get_animation_list():
			if key=="idle" or key.ends_with("/idle"):animation.get_animation(key).loop_mode=Animation.LOOP_LINEAR;animation.play(key);break
	painter.free()
	model.rotation.y=-0.3
	viewport.add_child(model)
	var camera=Camera3D.new()
	viewport.add_child(camera)
	camera.position=Vector3(1.6,1.3,2.7)
	camera.look_at(Vector3(0,0.8,0))
	var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-20,0);light.light_energy=2;viewport.add_child(light)
	var fill=OmniLight3D.new();fill.position=Vector3(-2,2,1);fill.omni_range=10;fill.light_energy=1.5;viewport.add_child(fill)

func _locker(box):
	label(box,"MAKE IT YOURS",27,cream,true)
	label(box,"NAME",13,Color("9db8c3"))
	var edit=LineEdit.new();edit.text=game.profile.name;edit.max_length=18;box.add_child(edit)
	edit.text_changed.connect(func(t):game.profile.name=t;game.save_profile())
	option(box,"Skin tone",game.catalog.STYLE.SKIN_NAMES,game.profile.skin,func(i):game.profile.skin=i;game.save_profile();show_menu("locker"))
	option(box,"Outfit",game.catalog.STYLE.OUTFIT_NAMES,game.profile.outfit,func(i):game.profile.outfit=i;game.save_profile();show_menu("locker"))
	option(box,"Tentacle style",game.catalog.STYLE.HAIR_STYLE_NAMES,game.profile.hair,func(i):game.profile.hair=i;game.save_profile();show_menu("locker"))
	option(box,"Headgear",game.catalog.STYLE.HAT_NAMES,game.profile.hat,func(i):game.profile.hat=i;game.save_profile();show_menu("locker"))
	option(box,"Eyes",game.catalog.STYLE.IRIS_NAMES,game.profile.eyes,func(i):game.profile.eyes=i;game.save_profile();show_menu("locker"))
	option(box,"Eyebrows",game.catalog.STYLE.BROW_NAMES,game.profile.brows,func(i):game.profile.brows=i;game.save_profile();show_menu("locker"))
	var presets: Array=game.catalog.STYLE.PRESETS
	option(box,"Preset look",["Custom"]+presets.map(func(p):return p.name),0,func(i):
		if i>0:game.profile.merge(presets[i-1].style,true);game.save_profile();show_menu("locker"))
	button(box,"SHUFFLE LOOK",func():
		for pair in [["hair",8],["skin",9],["outfit",10],["eyes",8],["hat",4],["brows",4]]:game.profile[pair[0]]=randi()%pair[1]
		game.save_profile();show_menu("locker"))
	button(box,"IMPORT PROFILE",func():_profile_file(false))
	button(box,"EXPORT PROFILE",func():_profile_file(true))
	label(box,"Your look and loadout are saved automatically.",16,Color("9db8c3"))
	_preview()

func slider(parent: Node,caption: String,value: float,minimum: float,maximum: float,callback: Callable):
	label(parent,caption.to_upper(),13,Color("9db8c3"))
	var s=HSlider.new();s.min_value=minimum;s.max_value=maximum;s.step=0.01;s.value=value;s.custom_minimum_size.y=28;parent.add_child(s);s.value_changed.connect(callback)

func _settings(box):
	label(box,"TUNE YOUR FLOW",27,cream,true)
	option(box,"Language / 语言",["English","简体中文"],1 if game.settings.lang=="zh" else 0,func(i):game.settings.lang="zh" if i==1 else "en";game.save_profile();show_menu("settings"))
	slider(box,"Mouse sensitivity",game.settings.sensitivity,0.2,3,func(v):game.settings.sensitivity=v;game.save_profile())
	slider(box,"Controller sensitivity",game.settings.padSensitivity,0.2,3,func(v):game.settings.padSensitivity=v;game.save_profile())
	slider(box,"Camera shake",game.settings.cameraShake,0,1,func(v):game.settings.cameraShake=v;game.save_profile())
	slider(box,"Controller vibration",game.settings.rumble,0,1,func(v):game.settings.rumble=v;game.save_profile())
	slider(box,"Aim assistance",game.settings.aimAssist,0,1,func(v):game.settings.aimAssist=v;game.save_profile())
	option(box,"Quality",["Low","Medium","High","Ultra"],["low","medium","high","ultra"].find(game.settings.quality),func(i):game.settings.quality=["low","medium","high","ultra"][i];game.apply_settings();game.save_profile())
	option(box,"Frame limit",["Unlimited","30","60","120","144","240"],[0,30,60,120,144,240].find(int(game.settings.fpsCap)),func(i):game.settings.fpsCap=[0,30,60,120,144,240][i];game.apply_settings();game.save_profile())
	slider(box,"Field of view",game.settings.fov,65,100,func(v):game.settings.fov=v;game.save_profile())
	for key in ["master","music","sfx"]:
		var k=key
		slider(box,key,game.settings[key],0,1,func(v):game.settings[k]=v;game.save_profile())
	for key in ["invertY","colorblind","showFps","fullscreen","shadows","bloom","minimap","aimAssistMouse"]:
		var k=key
		var check=CheckButton.new();check.text={"invertY":"Invert vertical aim","colorblind":"Yellow / blue ink palette","showFps":"Show FPS","fullscreen":"Fullscreen","shadows":"Shadows","bloom":"Glow","minimap":"Minimap","aimAssistMouse":"Mouse aim assistance"}[key];check.text=t(check.text);check.button_pressed=game.settings.get(key,false);box.add_child(check)
		check.toggled.connect(func(v):game.settings[k]=v;game.save_profile();game.apply_settings())

func _controls(box):
	label(box,"INK. SWIM. REPEAT.",27,cream,true)
	var instructions=["W A S D   /   Left stick        Move","Mouse   /   Right stick        Aim","Left click   /   RT                  Fire","Shift   /   LT                           Squid + refill","Space   /   A                          Jump / pistol roll","Right click / E   /   RB        Sub weapon","F   /   Y                                    Special","Tab / M   /   View                Tactical map","Map + 1–4                            Super jump","Map + 0                                Return to spawn","C                                             Cheer","Esc   /   Start                       Pause"]
	for text in instructions:label(box,text,17)
	var tips=label(box,"Cover the ground to win Turf War. Swim in your team’s ink to refill and move faster; inked walls can be climbed. Control every live zone to count down to zero. Avoid the water!",17,Color("9db8c3"));tips.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label(box,"MIT © 2026 Jayden Davis\nNative Godot conversion",14,Color("9db8c3"))

func _online(box):
	label(box,"MAKE WAVES TOGETHER",25,cream,true)
	label(box,"Godot multiplayer • up to eight players",16,Color("9db8c3"))
	label(box,"HOST ADDRESS",13,Color("9db8c3"))
	var address=LineEdit.new();address.text="127.0.0.1";address.placeholder_text="IP address or hostname";box.add_child(address)
	label(box,"UDP PORT",13,Color("9db8c3"))
	var port=SpinBox.new();port.min_value=1024;port.max_value=65535;port.value=27840;box.add_child(port)
	button(box,"HOST A ROOM",func():game.host_room(int(port.value)),true)
	button(box,"JOIN ROOM",func():game.join_room(address.text,int(port.value)))
	connection_label=label(box,game.network_status,16,Color("9db8c3"));connection_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if game.online:
		var own: Dictionary=game.peers.get(game.multiplayer.get_unique_id(),{})
		option(box,"Team",["Auto","Alpha","Bravo"],int(own.get("room_team",-1))+1,func(i):game.lobby_choice(i-1,false))
		button(box,"NOT READY" if own.get("ready",false) else "READY",func():game.lobby_choice(int(own.get("room_team",-1)),not own.get("ready",false)),true)
		button(box,"CHANGE LOADOUT",func():show_menu("loadout"))
		option(box,"Say hello",["Choose an emote","Yeah!","Nice!","Let's go!","One moment!"],0,func(i):
			if i>0:game.lobby_emote(i-1))
	if game.online and game.authoritative:button(box,"CONFIGURE & START",func():show_menu("setup"),true)
	if game.online:button(box,"DISCONNECT",func():game.disconnect_room();show_menu("online"))
	var info=label(box,"Connect Godot clients on your network. Internet hosts need UDP port forwarding. Browser-version room codes use a different protocol.",16,Color("9db8c3"));info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

func _results(box):
	var result=game.result
	label(box,"VICTORY!" if result.winner==game.local_actor.team else "NEXT WAVE IS YOURS",31,orange,true)
	label(box,result.reason,15,Color("9db8c3"))
	var coverage=game.stage.coverage()
	label(box,t("ALPHA  %.1f%%   /   BRAVO  %.1f%%") % coverage,24,cream,true)
	label(box,t("+%d XP   •   LEVEL %d") % [result.xp,game.profile.level],22,orange)
	label(box,"PLAYER                         TURF    K / D",14,Color("9db8c3"))
	for a in game.actors:label(box,"%-20s   %4d    %d / %d" % [a.nickname,int(a.turf),a.splats,a.deaths],17,game.colors[a.team].lightened(0.3))
	if not game.online or game.authoritative:button(box,"ONE MORE WAVE",func():game.start_match(),true)
	button(box,"MAIN MENU",game.return_to_menu)

func start_hud():
	if page:page.queue_free();page=null
	if overlay:overlay.queue_free()
	overlay=Control.new()
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	var top_bg=Panel.new();top_bg.position=Vector2(410,12);top_bg.size=Vector2(620,110);top_bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var top_style=StyleBoxFlat.new();top_style.bg_color=Color(0.035,0.075,0.10,0.8);top_style.set_corner_radius_all(16);top_bg.add_theme_stylebox_override("panel",top_style);overlay.add_child(top_bg)
	clock_label=label(overlay,"3:00",40,cream,true);clock_label.position=Vector2(650,22)
	score_label=label(overlay,"",22,cream,true);score_label.position=Vector2(460,78)
	info_label=label(overlay,"",19);info_label.position=Vector2(40,785)
	banner_label=label(overlay,"",30,orange,true);banner_label.position=Vector2(350,145);banner_label.size.x=750;banner_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	prompt_label=label(overlay,"",23,cream,true);prompt_label.position=Vector2(360,680);prompt_label.size.x=720;prompt_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	ink_bar=_bar(Vector2(42,833),Vector2(230,17),orange)
	hp_bar=_bar(Vector2(42,859),Vector2(230,8),Color("e8eedc"))
	special_bar=_bar(Vector2(1160,837),Vector2(230,16),Color("a8eece"))
	label(overlay,"SHIFT  SWIM / REFILL",13,cream).position=Vector2(42,805)
	label(overlay,"F  SPECIAL",13,cream).position=Vector2(1160,813)
	map_view=TextureRect.new();map_view.position=Vector2(1200,28);map_view.size=Vector2(200,220);map_view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;map_view.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.add_child(map_view)
	map_image=Image.create(180,220,false,Image.FORMAT_RGBA8)
	map_texture=ImageTexture.create_from_image(map_image);map_view.texture=map_texture
	drawing=Control.new();drawing.mouse_filter=Control.MOUSE_FILTER_IGNORE;drawing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.add_child(drawing);drawing.draw.connect(_draw_hud)
	screen="hud"
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func _bar(pos: Vector2,dimensions: Vector2,color: Color) -> ProgressBar:
	var bar=ProgressBar.new();bar.position=pos;bar.size=dimensions;bar.show_percentage=false
	var fill=StyleBoxFlat.new();fill.bg_color=color;fill.set_corner_radius_all(5);bar.add_theme_stylebox_override("fill",fill)
	var bg=StyleBoxFlat.new();bg.bg_color=Color("16212c");bg.set_corner_radius_all(5);bar.add_theme_stylebox_override("background",bg)
	overlay.add_child(bar)
	return bar

func banner(text: String):
	notice=text
	banner_time=3.0
	if screen=="online" and connection_label:connection_label.text=game.network_status+"\n"+text

func update(dt: float):
	banner_time=maxf(0,banner_time-dt)
	hit_flash=maxf(0,hit_flash-dt)
	if not overlay or not is_instance_valid(overlay) or not game.local_actor:return
	if game.paused:return
	overlay.visible=game.state=="playing"
	if not overlay.visible:return
	var a=game.local_actor
	var sec=maxi(0,ceili(game.time_left))
	clock_label.text="%d:%02d" % [sec/60,sec%60]
	var cov=game.stage.coverage()
	score_label.text=t("ALPHA  %.1f%%     vs     %.1f%%  BRAVO") % cov
	if game.mode=="zones":score_label.text=t("ALPHA %d  (+%d)     ZONE     BRAVO %d  (+%d)") % [ceili(game.zones.counts[0]),ceili(game.zones.penalties[0]),ceili(game.zones.counts[1]),ceili(game.zones.penalties[1])]
	if game.mode=="boss":score_label.text=t("HULLBREAKER  •  %d / %d HP  •  PHASE %d") % [game.boss.hp,game.boss.max_hp,game.boss.phase]
	info_label.text=t("%s   •   %dp   •   %d SPLATS") % [a.weapon.name,a.turf,a.splats]
	if game.settings.showFps:info_label.text+="   •   %d FPS" % Engine.get_frames_per_second()
	ink_bar.value=a.ink
	hp_bar.value=a.hp
	special_bar.value=100*a.special/float(a.weapon.specialCost)
	banner_label.text=notice if banner_time>0 else ""
	prompt_label.text=""
	if a.respawn>0:prompt_label.text=t("SPLATTED!   Back in %.1f") % a.respawn
	elif a.special_time>0:prompt_label.text=game.catalog.SPECIALS[a.special_id].name.to_upper()+"  %.1f" % a.special_time
	elif a.special>=float(a.weapon.specialCost):prompt_label.text=t("SPECIAL READY  •  F")
	elif a.ink<15:prompt_label.text=t("LOW INK  •  HOLD SHIFT IN YOUR INK")
	map_expanded=game.map_open
	map_view.visible=map_expanded or game.settings.minimap
	map_view.position=Vector2(500,160) if map_expanded else Vector2(1200,28)
	map_view.size=Vector2(440,550) if map_expanded else Vector2(200,220)
	if map_expanded:prompt_label.text="PICK A SPOT • CLICK TO LAUNCH VORTEX STRIKE" if a.kit.get("strike_aim",false) else "1–4  JUMP TO ALLY    •    0  HOME    •    CLICK A PIN"
	map_timer-=dt
	if map_timer<=0:_update_map();map_timer=0.35
	prompt_label.text=t(prompt_label.text)
	drawing.queue_redraw()

func map_point(pos: Vector3) -> Vector2:
	var b=game.stage.bounds
	return Vector2((pos.x-b.minX)/(b.maxX-b.minX)*180,(pos.z-b.minZ)/(b.maxZ-b.minZ)*220)

func _update_map():
	map_image.fill(Color("122a3b"))
	for cell in game.stage.turf_cells:
		var p=map_point(cell[2])
		var f: Dictionary=game.stage.faces[cell[0]]
		var value=int(f.cells[cell[1]])
		var color=game.colors[value-1] if value in [1,2] else Color("b7b9ac")
		var px=clampi(int(p.x),0,179);var py=clampi(int(p.y),0,219)
		map_image.fill_rect(Rect2i(mini(px,178),mini(py,218),2,2),color)
	for a in game.actors:
		if not a.alive() or (a.team!=game.local_actor.team and a.marked<=0):continue
		var p=map_point(a.position)
		map_image.fill_rect(Rect2i(clampi(int(p.x)-2,0,175),clampi(int(p.y)-2,0,215),5,5),Color.WHITE if a.is_local else game.colors[a.team].lightened(0.7))
	for g in game.combat.gadgets:
		if g.kind=="beacon" and g.team==game.local_actor.team:
			var p=map_point(g.pos)
			map_image.fill_rect(Rect2i(clampi(int(p.x)-2,0,175),clampi(int(p.y)-2,0,215),5,5),Color("a8eece"))
	map_texture.update(map_image)

func _draw_hud():
	if not game.local_actor:return
	var a=game.local_actor
	if hit_flash>0:drawing.draw_rect(Rect2(Vector2.ZERO,Vector2(1440,900)),Color(1,0.1,0.1,hit_flash*0.5))
	if map_expanded:return
	var center=Vector2(720,450)
	var radius=8+a.charge*15
	drawing.draw_arc(center,radius,0,TAU,32,Color.WHITE,2,true)
	drawing.draw_circle(center,2,orange)
	if a.weapon_id=="bow":
		for ring in 2:
			var fraction=clampf(a.charge/0.45,0,1) if ring==0 else clampf((a.charge-0.45)/0.55,0,1)
			drawing.draw_arc(center,25+ring*7,-PI/2,-PI/2+TAU*fraction,48,orange if ring==0 else cream,3,true)
	if a.sub_held:
		var pos: Vector3=a.position+Vector3.UP*1.04
		var vel=(game.combat.aim(a)+Vector3.UP*.3).normalized()*float(game.catalog.SUBS[a.sub_id].get("throwSpeed",13))
		for i in 32:
			vel.y-=24*.065
			var next=pos+vel*.065
			var hit=game.ray(pos,next,1)
			if not game.camera.is_position_behind(pos):drawing.draw_circle(game.camera.unproject_position(pos)*Vector2(1440,900)/Vector2(game.get_viewport().get_visible_rect().size),2.5,cream)
			if not hit.is_empty():break
			pos=next
		if a.sub_id=="shaker":
			for i in 3:drawing.draw_circle(center+Vector2((i-1)*14,50),5,orange if i<=int(a.sub_charge*2.999) else navy)
	for offset in [Vector2(-1,0),Vector2(1,0),Vector2(0,-1),Vector2(0,1)]:drawing.draw_line(center+offset*(radius+5),center+offset*(radius+11),Color.WHITE,2,true)
	var team_slots=[0,0]
	for i in game.actors.size():
		var actor=game.actors[i]
		var slot=team_slots[actor.team]
		team_slots[actor.team]+=1
		var x=450+slot*35 if actor.team==0 else 850+slot*35
		drawing.draw_circle(Vector2(x,45),10,game.colors[actor.team] if actor.alive() else Color("35434d"))

func click_map(pos: Vector2):
	if not map_expanded:return
	if game.local_actor.kit.get("strike_aim",false):
		var uv=(pos-map_view.position)/map_view.size
		if uv.x<0 or uv.y<0 or uv.x>1 or uv.y>1:return
		var bounds: Dictionary=game.stage.bounds
		game.request_strike(Vector3(lerpf(bounds.minX,bounds.maxX,uv.x),0,lerpf(bounds.minZ,bounds.maxZ,uv.y)))
		return
	var best=null
	var dist=35.0
	for a in game.actors:
		if a.team!=game.local_actor.team or a.is_local or not a.alive():continue
		var p=map_view.position+map_point(a.position)/Vector2(180,220)*map_view.size
		if p.distance_to(pos)<dist:best=a;dist=p.distance_to(pos)
	if best:game.request_jump(best.index);return
	for g in game.combat.gadgets:
		if g.kind!="beacon" or g.team!=game.local_actor.team:continue
		var p=map_view.position+map_point(g.pos)/Vector2(180,220)*map_view.size
		if p.distance_to(pos)<35:game.request_jump(-2-int(g.id));return

func _profile_file(exporting: bool):
	var dialog=FileDialog.new()
	dialog.access=FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE if exporting else FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters=PackedStringArray(["*.json ; INKWAVE profile"])
	dialog.current_file="inkwave-profile.json" if exporting else ""
	page.add_child(dialog)
	dialog.file_selected.connect(func(path):
		if exporting:
			var file=FileAccess.open(path,FileAccess.WRITE)
			if file:file.store_string(JSON.stringify({"profile":game.profile,"settings":game.settings},"  "))
		else:
			var value=JSON.parse_string(FileAccess.get_file_as_string(path))
			if value is Dictionary:
				var p: Dictionary=value.get("profile",value)
				if p.get("style") is Dictionary:p.merge(p.style,true)
				game.profile=game._valid_profile(p)
				for key in ["xp","level","wins","played"]:game.profile[key]=maxi(1 if key=="level" else 0,int(p.get(key,1 if key=="level" else 0)))
				game.save_profile();show_menu("locker")
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_ratio(0.75)
