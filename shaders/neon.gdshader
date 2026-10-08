shader_type spatial;
render_mode unshaded;
void fragment(){ALBEDO=COLOR.rgb;EMISSION=COLOR.rgb*(2.0+.1*sin(TIME*7.));}
