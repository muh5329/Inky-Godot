shader_type spatial;
render_mode cull_disabled;
uniform vec2 dimensions=vec2(1.0);
void fragment(){
 vec2 cell=abs(fract(UV*dimensions*7.0)-0.5);
 if(max(cell.x,cell.y)<0.38)discard;
 ALBEDO=vec3(0.23,0.29,0.32);METALLIC=0.75;ROUGHNESS=0.52;
}
