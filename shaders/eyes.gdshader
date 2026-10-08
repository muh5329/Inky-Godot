shader_type spatial;
uniform vec4 iris_color : source_color = vec4(.15,.6,.7,1.0);
varying vec3 eye;
void vertex(){eye=COLOR.rgb*2.0-1.0;}
void fragment(){
 float r=length(eye.xy);
 vec3 c=vec3(.92,.93,.88);
 float iris=1.0-smoothstep(.37,.40,r);
 float pupil=1.0-smoothstep(.17,.19,r);
 c=mix(c,iris_color.rgb,iris);
 c=mix(c,vec3(.005,.009,.013),pupil);
 c=mix(c,vec3(1.0),1.0-smoothstep(.05,.07,length(eye.xy-vec2(-.09,.13))));
 ALBEDO=c;ROUGHNESS=.23;SPECULAR=.55;
}
