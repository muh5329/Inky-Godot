shader_type spatial;
render_mode cull_back;
uniform sampler2D paint_atlas : filter_linear, repeat_disable;
uniform vec4 team_a : source_color = vec4(1.0,0.54,0.08,1.0);
uniform vec4 team_b : source_color = vec4(0.18,0.36,1.0,1.0);
uniform float paint_time=0.0;
uniform bool use_surface_library=false;
uniform sampler2DArray surface_albedo : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray surface_normal : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray surface_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 surface_slots[64];
uniform vec4 surface_remap[64];
varying vec3 world_pos;
varying vec3 face_normal;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;face_normal=MODEL_NORMAL_MATRIX*NORMAL;}
void fragment(){
 vec4 p=texture(paint_atlas,UV);
 float coverage=smoothstep(0.12,0.65,p.a);
 vec3 ink=mix(team_a.rgb,team_b.rgb,step(0.5,p.r));
 float pattern=floor(COLOR.a*64.0+.5);
 vec2 surface=UV2;
 float grain=hash(floor(surface*90.0));
 float tone=.91+grain*.09;
 if(pattern==17.0||pattern==6.0||pattern==1.0||pattern==26.0){
   vec2 q=surface*vec2(.6,5.0);
   tone=(.85+.15*hash(vec2(floor(q.y),0.0)))*mix(.45,1.0,smoothstep(.015,.045,min(fract(q.y),1.0-fract(q.y))));
   tone*=.92+.08*sin(surface.x*70.0+sin(surface.y*25.0));
 }else if(pattern==28.0||pattern==13.0||pattern==16.0){
   vec2 q=surface*vec2(4.0,8.0);q.x+=mod(floor(q.y),2.0)*.5;
   vec2 gap=min(fract(q),1.0-fract(q));
   tone=(.7+.3*hash(floor(q)))*mix(.6,1.0,smoothstep(.015,.045,min(gap.x,gap.y)));
 }else if(pattern==2.0||pattern==8.0||pattern==29.0||pattern==30.0){
   vec2 q=surface*(pattern==30.0?vec2(.83,2.5):vec2(.83));
   vec2 gap=min(fract(q),1.0-fract(q));
   tone*=mix(.55,1.0,smoothstep(.006,.016,min(gap.x,gap.y)));
 }else if(pattern==5.0){tone*=.7+.3*smoothstep(-.7,.7,sin(surface.x*12.0));}
 else if(pattern>=24.0&&pattern<=27.0){tone*=.7+.3*smoothstep(.02,.09,fract(surface.y*3.0));}
 vec3 base=COLOR.rgb*tone;
 vec3 orm=vec3(1.0,.86,0.0);
 if(use_surface_library){
   int slot=clamp(int(pattern),0,63);
   slot=int(abs(face_normal.y)>.5?surface_remap[slot].y:surface_remap[slot].x);
   vec4 def=surface_slots[clamp(slot,0,63)];
   vec3 at=vec3(surface*def.y,def.x);
   vec4 tex=texture(surface_albedo,at);
   base=def.z<.5?tex.rgb:(def.z<1.5?tex.rgb*COLOR.rgb:tex.rgb+COLOR.rgb*tex.a*1.25);
   orm=texture(surface_orm,at).rgb;
   vec3 n=texture(surface_normal,at).rgb*2.0-1.0;
   NORMAL=normalize(NORMAL+(TANGENT*n.x+BINORMAL*n.y)*.5*(1.0-coverage));
 }
 ALBEDO=mix(base,ink*.9,coverage);
 AO=mix(orm.r,1.0,coverage);METALLIC=orm.b*(1.0-coverage);
 float age=mod(paint_time-p.g*255.0+255.0,255.0);
 ROUGHNESS=mix(orm.g,mix(.2,.45,smoothstep(1.0,18.0,age)),coverage);
 SPECULAR=mix(.25,.65,coverage);
}
