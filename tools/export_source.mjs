// Rebuild portable data and glTF assets directly from the MIT-licensed original.
import fs from 'node:fs';
import path from 'node:path';
import {createCanvas, Image, Canvas, ImageData} from '@napi-rs/canvas';
import * as THREE from 'three';
import {GLTFExporter} from 'three/addons/exporters/GLTFExporter.js';
globalThis.document={createElement:(tag)=>{if(tag==='canvas'){const c=createCanvas(256,256);Object.defineProperty(c,'data',{value:undefined});return c;}return {style:{}};},createElementNS:(_,tag)=>document.createElement(tag)};
globalThis.window={devicePixelRatio:1}; globalThis.Image=Image; globalThis.ImageData=ImageData; globalThis.HTMLCanvasElement=Canvas;
globalThis.FileReader=class {readAsArrayBuffer(b){b.arrayBuffer().then(x=>{this.result=x;this.onloadend?.();});} readAsDataURL(b){b.arrayBuffer().then(x=>{this.result=`data:${b.type};base64,${Buffer.from(x).toString('base64')}`;this.onloadend?.();});}};
const C=await import('../source_reference/src/config.js');
const {MAP_LAYOUTS}=await import('../source_reference/src/world/maps.js');
const {Level}=await import('../source_reference/src/world/level.js');
const {PropKit}=await import('../source_reference/src/world/props.js');
const {dressingFor}=await import('../source_reference/src/world/dressing.js');
const {layoutFor,inMode}=await import('../source_reference/src/world/variants.js');
const {G}=await import('../source_reference/src/core/ctx.js');
G.teamColors=[new THREE.Color('#ff8a14'),new THREE.Color('#2f5bff')]; G.settings={quality:'medium'};
const root=path.resolve(import.meta.dirname,'..');
function browSubset(geo,bones,want){const g=geo.clone(),ids=new Set([bones.indexOf('browL'),bones.indexOf('browR')]);const sk=g.attributes.skinIndex, sw=g.attributes.skinWeight,idx=g.index?.array||Array.from({length:g.attributes.position.count},(_,i)=>i),out=[];for(let i=0;i<idx.length;i+=3){let brow=false;for(let j=0;j<3;j++){const v=idx[i+j];for(let k=0;k<4;k++)if(ids.has(sk.array[v*4+k])&&sw.array[v*4+k]>.1)brow=true;}if(brow===want)out.push(idx[i],idx[i+1],idx[i+2]);}g.setIndex(out);return g;}

const write=(p,data)=>fs.writeFileSync(path.join(root,p),JSON.stringify(data));
const STYLE=await import('../source_reference/src/game/character-style.js');
const {ZH_PHRASES}=await import('../source_reference/src/i18n/zh.js');
const {BOSS}=await import('../source_reference/src/boss/boss.js');
const {MOVES,HZ}=await import('../source_reference/src/boss/bossHazards.js');
write('data/catalog.json',{...C,STYLE,ZH_PHRASES,BOSS,BOSS_MOVES:MOVES,BOSS_HAZARDS:HZ});
fs.copyFileSync(path.join(root,'source_reference/LICENSE'),path.join(root,'LICENSE'));
fs.writeFileSync(path.join(root,'source_reference/.gdignore'),'');
fs.writeFileSync(path.join(root,'tools/.gdignore'),'');
async function glb(scene,file,animations=[]){
 const instanced=[];
 scene.traverse(o=>{if(o.isInstancedMesh)instanced.push(o);});
 for(const o of instanced){const group=new THREE.Group();group.copy(o,false);group.type='Group';group.isInstancedMesh=false;
 for(let i=0;i<o.count;i++){const m=new THREE.Mesh(o.geometry,o.material);const matrix=new THREE.Matrix4();o.getMatrixAt(i,matrix);matrix.decompose(m.position,m.quaternion,m.scale);if(o.instanceColor){const c=new THREE.Color();o.getColorAt(i,c);m.material=m.material.clone();m.material.color?.multiply(c);}group.add(m);}o.parent.add(group);o.parent.remove(o);}
 scene.updateMatrixWorld(true);
 scene.traverse(o=>{if(!o.material)return;const fix=m=>{if(m.isShaderMaterial)return new THREE.MeshStandardMaterial({color:m.uniforms?.uColor?.value||m.uniforms?.uInk?.value||'#879ba8',vertexColors:!!o.geometry?.attributes.color,roughness:.55,side:m.side});return m;};o.material=Array.isArray(o.material)?o.material.map(fix):fix(o.material);});
 const out=await new GLTFExporter().parseAsync(scene,{binary:true,onlyVisible:true,animations,trs:animations.length>0});
 const buf=Buffer.from(out),jsonLen=buf.readUInt32LE(12);const json=JSON.parse(buf.subarray(20,20+jsonLen).toString());
 for(const a of json.animations||[])a.channels=a.channels.filter(c=>c.target.node!==undefined);
 let jb=Buffer.from(JSON.stringify(json));const padding=(4-jb.length%4)%4;jb=Buffer.concat([jb,Buffer.alloc(padding,32)]);
 const rest=buf.subarray(20+jsonLen);const header=Buffer.alloc(20);buf.copy(header,0,0,20);header.writeUInt32LE(20+jb.length+rest.length,8);header.writeUInt32LE(jb.length,12);
 fs.writeFileSync(path.join(root,file),Buffer.concat([header,jb,rest]));
}
const mode=process.argv[2]||'maps';
if(mode==='maps'||mode==='levels')for(const [id,layout] of Object.entries(MAP_LAYOUTS))for(const variant of ['turf','zones']){
 const scene=new THREE.Scene();const kit=new PropKit(scene,{castShadow:true,quality:'medium'});let extra=[];
 for(const it of dressingFor(id)){if(inMode(it,variant)){const r=kit.add(it.type,it);if(r?.colliders)extra.push(...r.colliders);}}
 kit.build();
 const L=new Level(layoutFor(layout,variant),extra);
 const size=2048,ppm=10,pad=2;let x=4,y=4,h=0;
 const faces=L.faces.filter(f=>f.paintable).sort((a,b)=>b.sv-a.sv);
 for(const f of faces){let w=Math.ceil(f.su*ppm)+pad*2,hh=Math.ceil(f.sv*ppm)+pad*2;if(x+w>size){x=4;y+=h;h=0;}f.atlas={x,y,ppm,pad};x+=w;h=Math.max(h,hh);}
 if(y+h>size)throw Error('atlas overflow '+id+' '+(y+h));
 const geo=L.buildGeometry(size);geo.setAttribute('uv',geo.getAttribute('paintUv'));geo.setAttribute('uv1',geo.getAttribute('faceUv'));
 const cc=geo.getAttribute('color'),fd=geo.getAttribute('faceData'),rgba=[];for(let k=0;k<cc.count;k++)rgba.push(cc.getX(k),cc.getY(k),cc.getZ(k),fd.getX(k)/64);geo.setAttribute('color',new THREE.Float32BufferAttribute(rgba,4));
 for(const k of Object.keys(geo.attributes))if(!['position','normal','color','uv','uv1'].includes(k))geo.deleteAttribute(k);
 const levelScene=new THREE.Scene();let mesh=new THREE.Mesh(geo,new THREE.MeshStandardMaterial({vertexColors:true,roughness:.8}));mesh.name='PaintableStage';levelScene.add(mesh);
 await glb(levelScene,`assets/models/${id}_${variant}_level.glb`);
 if(mode==='maps')await glb(scene,`assets/models/${id}_${variant}_props.glb`);
 const blocks=L.blocks.map(b=>({id:b.id,center:b.center.toArray(),half:b.half.toArray(),axes:b.axes.map(v=>v.toArray()),solid:b.solid,grate:b.grate,rail:b.rail,faces:b.faces}));
 const ff=L.faces.map(f=>({...f,n:f.n.toArray(),u:f.u.toArray(),v:f.v.toArray(),origin:f.origin.toArray(),color:'#'+f.color.getHexString()}));
 // Ground navigation samples keep the original multi-level stage geometry, including prop collision.
 const nav=[];const bb=layout.bounds,step=1.4;let ni=0;
 for(let z=bb.minZ;z<=bb.maxZ;z+=step)for(let xx=bb.minX;xx<=bb.maxX;xx+=step){const yy=L.groundHeight(xx,z,12);if(Number.isFinite(yy)&&yy>=-1.4&&!L.pointInside(new THREE.Vector3(xx,yy+.8,z),.25))nav.push([ni,xx,yy,z]);ni++;}
 write(`data/${id}_${variant}.json`,{id,bounds:layout.bounds,spawnPads:layout.spawnPads,zones:layout.zones||{},atlasSize:size,blocks,faces:ff,nav,navStep:step,navWidth:Math.floor((bb.maxX-bb.minX)/step)+1});
 console.log(id,variant,blocks.length,ff.length,'nav',nav.length);
}
if(mode==='characters'){
 const {Character}=await import('../source_reference/src/game/character.js');
 for(const weapon of C.WEAPON_ORDER){
 const ch=new Character({name:'Inkwave',weapon,color:'#ff8a14',style:{hair:0,skin:1,outfit:0,eyes:0}});ch.lod.force=1;
 const s={time:0,speed:0,localMove:{x:0,z:0},grounded:true,vy:0,aimPitch:0,firing:false,charge:0,rolling:false,form:'kid',ink:1,lowInk:false,special:0,invuln:false,hp:1};
 for(let i=0;i<60;i++){s.time=i/30;ch.update(1/30,s);}
 let count=0;ch.root.traverse(o=>{o.name='Part_'+count++;if(o.material){const mats=Array.isArray(o.material)?o.material:[o.material];for(const m of mats){if(m===ch.mats.hair)m.name='HairInk';else if(m===ch.mats.squid||m===ch.mats.fill)m.name='TeamInk';else if(m===ch.mats.skin)m.name='Skin';else if(m===ch.mats.cloth)m.name='Outfit';else if(m===ch.mats.eye)m.name='Eyes';
 if(m===ch.mats.cloth && o.geometry?.attributes.aEx){o.geometry=o.geometry.clone();const g=o.geometry,ex=g.attributes.aEx,cl=g.attributes.aCloth,po=g.attributes.position;const arr=[],bind=[];for(let i=0;i<ex.count;i++){arr.push(po.getZ(i)+.5,cl?cl.getX(i)/32:0,cl?cl.getZ(i):0,ex.getX(i)/16);bind.push(po.getX(i),po.getY(i));}g.setAttribute('color',new THREE.Float32BufferAttribute(arr,4));g.setAttribute('uv1',new THREE.Float32BufferAttribute(bind,2));m.vertexColors=true;}
 if(m===ch.mats.eye && o.geometry?.attributes.aEyeS){o.geometry=o.geometry.clone();const g=o.geometry,ex=g.attributes.aEyeS;const arr=[];for(let i=0;i<ex.count;i++)arr.push(ex.getX(i)*.5+.5,ex.getY(i)*.5+.5,ex.getZ(i)*.5+.5);g.setAttribute('color',new THREE.Float32BufferAttribute(arr,3));} }}});
 const clips=[];
 write(`data/rig_${weapon}.json`,Object.fromEntries(Object.entries(ch.bones).map(([k,b])=>[k,b.name])));
 for(const state of ['idle','run','fire','charge','air','throw','hurt','roll','victory','defeat','cheer']){
 ch.setDance(['victory','defeat'].includes(state)?state:null);s.speed=state==='run'?6:0;s.localMove.z=state==='run'?1:0;s.firing=['fire','charge'].includes(state);s.charge=state==='charge'?1:0;s.grounded=state!=='air';s.vy=state==='air'?4:0;s.rolling=state==='roll';
 const nodes=[];ch.root.traverse(o=>nodes.push(o));const samples=new Map(nodes.map(n=>[n,{p:[],q:[],s:[]}])) ;const times=[];
 for(let i=0;i<=40;i++){s.time+=1/30;if(i===0&&['throw','hurt','roll','cheer'].includes(state))ch.trigger(state);if(state==='fire'&&i%3===0)ch.trigger('shoot');ch.update(1/30,s);times.push(i/30);for(const n of nodes){const k=samples.get(n);k.p.push(...n.position.toArray());k.q.push(...n.quaternion.toArray());k.s.push(...n.scale.toArray());}}
 const tracks=[];for(const [n,k]of samples){tracks.push(new THREE.VectorKeyframeTrack(n.name+'.position',times,k.p),new THREE.QuaternionKeyframeTrack(n.name+'.quaternion',times,k.q),new THREE.VectorKeyframeTrack(n.name+'.scale',times,k.s));}clips.push(new THREE.AnimationClip(state,-1,tracks));
 }
 ch.setDance(null);s.speed=0;s.firing=false;for(let i=0;i<30;i++)ch.update(1/30,s);
 await glb(ch.root,`assets/models/kid_${weapon}.glb`,clips);
 console.log('character',weapon);ch.dispose();
 }

}

if(mode==='appearance'){
 const {Character}=await import('../source_reference/src/game/character.js');
 for(let hair=0;hair<8;hair++)for(let hat=0;hat<4;hat++){
 const ch=new Character({name:'Inkwave',weapon:'shooter',color:'#ff8a14',style:{hair,hat,skin:1,outfit:0,eyes:0}});ch.lod.force=1;
 let count=0;ch.root.traverse(o=>{o.name='Part_'+count++;if(o.isMesh){if(o.material===ch.mats.hair){o.name='AppearanceHair';o.material.name='HairInk';o.geometry=browSubset(o.geometry,Object.keys(ch.bones),false);}else o.visible=false;}});
 await glb(ch.root,`assets/models/hair_${hair}_${hat}.glb`);ch.dispose();console.log('hair',hair,hat);
 }
}

if(mode==='brows'||mode==='appearance'){
 const {Character}=await import('../source_reference/src/game/character.js');
 for(let brows=0;brows<4;brows++){
 const ch=new Character({name:'Inkwave',weapon:'shooter',color:'#ff8a14',style:{hair:0,hat:0,brows,skin:1,outfit:0,eyes:0}});ch.lod.force=1;
 let count=0;ch.root.traverse(o=>{o.name='Part_'+count++;if(o.isMesh){if(o.material===ch.mats.hair){o.name='AppearanceBrow';o.material.name='BrowInk';o.geometry=browSubset(o.geometry,Object.keys(ch.bones),true);}else o.visible=false;}});
 await glb(ch.root,`assets/models/brows_${brows}.glb`);ch.dispose();console.log('brows',brows);
 }
 const ch=new Character({name:'Inkwave',weapon:'shooter',color:'#ff8a14'});ch.lod.force=1;
 ch.kid.visible=false;ch.squidRoot.visible=true;ch.squidRoot.scale.setScalar(1);ch.squid.pivot.scale.setScalar(1);
 ch.squidRoot.traverse(o=>{if(o.isMesh){o.visible=o!==ch.squid.ghost;if(o.material===ch.mats.squid)o.material.name='TeamInk';}});
 await glb(ch.squidRoot,'assets/models/squid.glb');ch.dispose();console.log('squid');
}

if(mode==='boss'){
 const {BossModel,Crablet}=await import('../source_reference/src/boss/bossModel.js');
 const boss=new BossModel({quality:'medium'});await boss.ready;
 let count=0;boss.root.traverse(o=>{o.name='BossPart_'+count++;});
 for(const [key,m] of Object.entries(boss.mats))m.name='Boss_'+key;
 const clips=[],hitFrames={};
 for(const state of ['idle','walk',...Object.keys(MOVES).flatMap(m=>['tele','act','rec'].map(p=>m+'_'+p))]){
 hitFrames[state]=[];const [move,phase]=state.split('_');const duration=phase?Math.max(.8,MOVES[move][phase]||1.5):2;
 const nodes=[];boss.root.traverse(o=>nodes.push(o));const samples=new Map(nodes.map(n=>[n,{p:[],q:[],s:[]}])),times=[];
 for(let i=0;i<=Math.ceil(duration*20);i++){
 boss.update(.05,{speed:state==='walk'?2:0,turn:0,move:phase?move:null,moveT:i*.05,movePhase:phase||null,phaseDur:duration,phase:1,stunned:false,hurt:0,dead:false,aim:null});times.push(i*.05);hitFrames[state].push(boss.hitShapes.map(h=>({socket:h.socket,r:h.r,weak:h.weak,active:h.active,pos:h.pos.toArray()})));
 for(const n of nodes){const v=samples.get(n);v.p.push(...n.position.toArray());v.q.push(...n.quaternion.toArray());v.s.push(...n.scale.toArray());}}
 const tracks=[];for(const [n,v] of samples)tracks.push(new THREE.VectorKeyframeTrack(n.name+'.position',times,v.p),new THREE.QuaternionKeyframeTrack(n.name+'.quaternion',times,v.q),new THREE.VectorKeyframeTrack(n.name+'.scale',times,v.s));
 clips.push(new THREE.AnimationClip(state,-1,tracks));
 }
 write('data/boss_hit_shapes.json',hitFrames);await glb(boss.root,'assets/models/hullbreaker.glb',clips);
 const crab=new Crablet({quality:'medium'});await crab.ready;await glb(crab.root,'assets/models/crablet.glb');console.log('Boss animations and crablet exported');
}

if(mode==='devices'){
 await import('../source_reference/src/game/kits/index.js');
 const {getSubDef}=await import('../source_reference/src/game/character-weapons.js');
 const {getSpecialProp,SPECIAL_PROP_KINDS}=await import('../source_reference/src/game/special-props.js');
 const build=async(def,file)=>{const root=new THREE.Group();const add=(data,prefix='')=>{for(const [key,value] of Object.entries(data)){if(value?.isBufferGeometry){const ink=(prefix+key).toLowerCase().includes('ink');const mat=new THREE.MeshStandardMaterial({color:ink?'#ff8a14':'#ffffff',vertexColors:!ink,roughness:ink?.16:.48});mat.name=ink?'TeamInk':'DeviceBody';const mesh=new THREE.Mesh(value,mat);mesh.name=prefix+key;root.add(mesh);}}};add(def);await glb(root,file);};
 for(const id of C.SUB_ORDER){await build(getSubDef(id),`assets/models/sub_${id}.glb`);console.log('sub',id);}
 for(const id of SPECIAL_PROP_KINDS){await build(getSpecialProp(id),`assets/models/special_${id}.glb`);console.log('special',id);}
}

if(mode==='lobby'){
 const {LobbySet}=await import('../source_reference/src/game/lobbySet.js');
 const set=new LobbySet(null,{quality:'low'});await set.ready;
 fs.mkdirSync(path.join(root,'assets/lobby'),{recursive:true});
 for(const [name,t] of Object.entries(set.tex))if(t.image?.toBuffer)fs.writeFileSync(path.join(root,'assets/lobby',name+'.png'),t.image.toBuffer('image/png'));
 write('data/lobby.json',{spots:set.spots.map(s=>({pos:s.pos.toArray(),yaw:s.yaw})),hubSpot:{pos:set.hubSpot.pos.toArray(),yaw:set.hubSpot.yaw},camera:{pos:set.camera.pos.toArray(),target:set.camera.target.toArray(),fov:set.camera.fov},hubCamera:{pos:set.hubCamera.pos.toArray(),target:set.hubCamera.target.toArray(),fov:set.hubCamera.fov},lanes:set.spots.map((_,i)=>set.lanes(i).map(p=>p.toArray()))});
 set.root.traverse(o=>{
  if(!o.isMesh)return;
  const g=o.geometry.clone();o.geometry=g;
  if(o.material===set.mats.surface){
   const c=g.attributes.color,a=g.attributes.aSurf,d=g.attributes.aDec,rgba=[],uv=[];
   for(let i=0;i<c.count;i++){rgba.push(c.getX(i),c.getY(i),c.getZ(i),(a.getX(i)*8+d.getZ(i))/128);uv.push(d.getX(i),d.getY(i));}
   g.setAttribute('color',new THREE.Float32BufferAttribute(rgba,4));g.setAttribute('uv1',new THREE.Float32BufferAttribute(uv,2));o.material=new THREE.MeshStandardMaterial({vertexColors:true});o.material.name='LobbySurface';
  }else if(o.material===set.mats.neon){
   const n=g.attributes.aNeon,rgba=[];for(let i=0;i<n.count;i++){const c=[set.U.uTeamA.value,set.U.uTeamB.value,new THREE.Color('#20ff60')][Math.min(2,Math.round(n.getX(i)))];rgba.push(c.r,c.g,c.b);}
   g.setAttribute('color',new THREE.Float32BufferAttribute(rgba,3));o.material=new THREE.MeshStandardMaterial({vertexColors:true});o.material.name='LobbyNeon';
  }else if(o.material===set.mats.ground){o.material.name='LobbyGround';}
  else if(o.material===set.mats.sky||o.material===set.mats.glow||o.material===set.mats.steam){o.visible=false;}
  else if(o.material.isShaderMaterial){const u=o.material.uniforms;o.material=new THREE.MeshBasicMaterial({color:u.uCol?.value||'#ffffff',map:u.map?.value||null,transparent:true,opacity:.25,depthWrite:false,side:THREE.DoubleSide});}
  for(const key of Object.keys(g.attributes))if(!['position','normal','uv','uv1','color'].includes(key))g.deleteAttribute(key);
 });
 await glb(set.root,'assets/models/lobby.glb');console.log('lobby exported');
}
