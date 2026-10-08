shader_type spatial;
render_mode cull_disabled;
uniform sampler2DArray surface_albedo : filter_linear_mipmap, repeat_enable;
uniform sampler2DArray surface_normal : filter_linear_mipmap, repeat_enable;
uniform sampler2DArray surface_orm : filter_linear_mipmap, repeat_enable;
uniform sampler2D decals : source_color, filter_linear_mipmap;
uniform vec4 slots[12];
uniform vec3 team_a : source_color=vec3(1,.25,.01);
uniform vec3 team_b : source_color=vec3(.02,.1,1);
uniform bool ground=false;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;}
void fragment(){
 float packed=floor(COLOR.a*128.0+.5);
 int slot=int(floor(packed/8.0));float mode=mod(packed,8.0);
 if(ground){slot=11;mode=0.0;}
 vec4 meta=slots[clamp(slot,0,11)];
 vec2 uv=ground?world.xz:UV;
 vec4 tex=texture(surface_albedo,vec3(uv*meta.y,meta.x));
 vec3 orm=texture(surface_orm,vec3(uv*meta.y,meta.x)).rgb;
 vec3 color=ground?vec3(.075,.09,.12):COLOR.rgb;
 if(slot>0){color=meta.z>1.5?tex.rgb+color*tex.a*1.25:(meta.z>.5?color*tex.rgb*1.25:tex.rgb);}
 if(slot==9&&tex.a<.5)discard;
 if(mode>.5){
  vec4 d=texture(decals,UV2);
  if(mod(mode+.5,2.0)<1.0)d.rg=d.gr;
  if(mode>2.5&&d.a<.08)discard;
  color=mix(color,team_a*d.r*.85+team_b*d.g*.85+vec3(.72)*d.b,d.a);
 }
 ALBEDO=color*mix(.65,1.,orm.r);
 ROUGHNESS=ground?.16:clamp(orm.g,.12,.95);
 METALLIC=ground?.25:0.0;
 NORMAL_MAP=texture(surface_normal,vec3(uv*meta.y,meta.x)).rgb;
 NORMAL_MAP_DEPTH=slot==0?0.:.65;
}
