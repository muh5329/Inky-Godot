shader_type spatial;
render_mode cull_disabled;
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;VERTEX.y+=sin(wp.x*.4+TIME)*.08+cos(wp.z*.3+TIME*1.3)*.06;}
void fragment(){float w=sin(wp.x*.8+sin(wp.z*.7+TIME)+TIME*.8)*.5+.5;ALBEDO=mix(vec3(.04,.30,.38),vec3(.12,.57,.64),w*.55);ROUGHNESS=.22;SPECULAR=.8;}
