"""Translate the original procedural wardrobe graphics to Godot shader syntax."""
from pathlib import Path
import re
root=Path(__file__).resolve().parent.parent
src=(root/'source_reference/src/game/character-mats.js').read_text()
def block(name):return re.search(r'const '+name+r' = /\* glsl \*/`(.*?)`;',src,re.S)[1]
noise=block('NOISE');cloth=block('CLOTH_GLSL').replace('${EMBLEM}',block('EMBLEM'))
cloth=re.sub(r'uniform[^;]+;', '',cloth)
cloth=re.sub(r'varying[^;]+;', '',cloth)
for source,target in {'uTeam':'team_color.rgb','uShirt':'shirt.rgb','uShorts':'shorts.rgb','uShoe':'shoe.rgb','uSole':'sole.rgb','uSock':'sock.rgb','uStrap':'strap.rgb','uPattern':'pattern'}.items():cloth=cloth.replace(source,target)
cloth=cloth.replace('const int SEG[10] = int[10](', 'const int SEG[10] = int[10](')
header='shader_type spatial;\n'
for name in ['team_color','shirt','shorts','shoe','sole','sock','strap']:header+=f'uniform vec4 {name} : source_color;\n'
header+='uniform float pattern=0.0;\nvarying vec3 vCloth;\nvarying vec3 bind_pos;\n'
vertex='\nvoid vertex(){vCloth=vec3(COLOR.g*32.0,0.0,COLOR.b);bind_pos=vec3(UV2,COLOR.r-.5);}\n'
frag='''
void fragment(){
 float slot=floor(COLOR.a*16.0+.5),part=floor(vCloth.x+.5);
 vec3 p=bind_pos;
 vec3 c=vec3(1.0);
 if(slot==1.0)c=team_color.rgb;
 else if(slot==2.0)c=iwShirtCol(p,UV,part);
 else if(slot==3.0)c=shorts.rgb;
 else if(slot==4.0)c=shoe.rgb;
 else if(slot==5.0)c=sock.rgb;
 else if(slot==6.0)c=sole.rgb;
 else if(slot==7.0)c=strap.rgb;
 else if(slot==8.0)c=iwContrast(shoe.rgb);
 else if(slot==9.0)c=mix(sole.rgb*.3+vec3(.035),vec3(.09,.09,.1),.35);
 else if(slot==10.0)c=vec3(.78,.8,.84);
 else if(slot==11.0)c=strap.rgb*.55+vec3(.02);
 else if(slot==12.0)c=mix(sock.rgb,vec3(.96),.6);
 else if(slot==13.0)c=team_color.rgb*.62;
 else if(slot==14.0)c=iwTrimCol();
 if(part==1.0&&p.z>0.0){
  vec2 q=vec2(p.x,p.y-.826);float r=.038;
  if(pattern==1.0||pattern==4.0){q=vec2(p.x,p.y-.927);r=.0135;}
  if(pattern==2.0){q=vec2(p.x,p.y-.818);r=.032;}
  if(pattern==3.0){q=vec2(p.x,p.y-.8);r=.028;}
  if(pattern==6.0){q=vec2(p.x-.05,p.y-.905);r=.0125;}
  if(pattern==7.0){q=vec2(p.x,p.y-.862);r=.03;}
  if(pattern==9.0){q=vec2(p.x-.048,p.y-.925);r=.0115;}
  if(pattern!=5.0&&pattern!=8.0){vec2 emblem=iwEmblem(q,r);c=mix(c,team_color.rgb,emblem.x);c=mix(c,shirt.rgb*1.02+vec3(.02),emblem.x*emblem.y);}
  if(pattern==8.0){float d=iwDigitSD(vec2(p.x,p.y-.8)/.029,8)*.029;c=mix(c,vec3(.09),iwFill(d-.0034));c=mix(c,team_color.rgb,iwFill(d));}
  if(pattern==9.0){float tape=iwFill(abs(p.x)-.0046)*step(p.y,.994);c=mix(c,shirt.rgb*.45+vec3(.01),tape);float teeth=iwFill(abs(p.x)-.0021)*step(.5,fract(p.y/.0034));c=mix(c,vec3(.76),teeth);}
 }
 ALBEDO=c;ROUGHNESS=.82;METALLIC=slot==10.0?.7:0.0;
}
'''
(root/'shaders/cloth.gdshader').write_text(header+noise+cloth+vertex+frag)
