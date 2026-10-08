// Render the original procedural score and SFX into portable native PCM assets.
import fs from 'node:fs';
import path from 'node:path';
import wae from 'web-audio-engine';
globalThis.OfflineAudioContext = wae.OfflineAudioContext;
const A = await import('../source_reference/src/audio/audio.js');
const M = await import('../source_reference/src/audio/music.js');
await import('../source_reference/src/game/kits/index.js');
const SR=32000, root=path.resolve(import.meta.dirname,'../assets/audio');
fs.mkdirSync(root,{recursive:true});
const manifest={source:'98ea29694ab3eebaaeaa995c2b525ac883a48de5',sampleRate:SR,sfx:{},music:{}};
function engine(seconds){const ctx=new OfflineAudioContext(2,Math.ceil(seconds*SR),SR);const eng=new A.AudioEngine({context:ctx,seed:1234,music:false,raw:true});eng.init();eng.setVolumes({master:1,sfx:1,music:1});eng.master.gain.value=eng.sfxBus.gain.value=eng.musicBus.gain.value=1;return {ctx,eng};}
function write(name,buf,trim=false){let n=buf.length;const channels=[buf.getChannelData(0),buf.getChannelData(1)];if(trim){while(n>SR*.08&&Math.max(Math.abs(channels[0][n-1]),Math.abs(channels[1][n-1]))<.0001)n--;n=Math.min(buf.length,n+Math.floor(.025*SR));}const b=Buffer.alloc(44+n*4);b.write('RIFF');b.writeUInt32LE(b.length-8,4);b.write('WAVEfmt ',8);b.writeUInt32LE(16,16);b.writeUInt16LE(1,20);b.writeUInt16LE(2,22);b.writeUInt32LE(SR,24);b.writeUInt32LE(SR*4,28);b.writeUInt16LE(4,32);b.writeUInt16LE(16,34);b.write('data',36);b.writeUInt32LE(n*4,40);let peak=0;for(let i=0;i<n;i++)for(let c=0;c<2;c++){const v=channels[c][i];if(!Number.isFinite(v))throw Error('Nonfinite sample '+name);peak=Math.max(peak,Math.abs(v));b.writeInt16LE(Math.round(Math.max(-1,Math.min(1,v))*32767),44+(i*2+c)*2);}fs.writeFileSync(path.join(root,name+'.wav'),b);return {seconds:n/SR,peak};}
const filter=process.argv[2];
for(const [name,d] of Object.entries(A.SFX)){
 if(filter&&filter!=='sfx'&&filter!==name)continue;
 const {ctx,eng}=engine(d.loop?4:6);
 eng.play(name,{at:0.01});
 const stats=write('sfx_'+name,await ctx.startRendering(),true);
 manifest.sfx[name]={...stats,loop:!!d.loop};console.log('SFX',name,stats.seconds.toFixed(2));
}
if(!filter||filter==='music')for(const [id,song] of Object.entries(M.SONGS)){
 const s=M.getSong(id), bar=240/s.bpm,seconds=s.bars.length*bar;
 const {ctx,eng}=engine(seconds+2);
 const m=new M.MusicEngine();m._init(ctx,eng.musicBus,{offline:true});m.play(id,{fade:0,seed:7});
 for(let t=0;t<seconds+2;t+=.05)m.advance(t);
 const stats=write('music_'+id,await ctx.startRendering());
 manifest.music[id]={...stats,name:song.name,bpm:s.bpm,loopFrom:s.loopFrom*bar,loopEnd:seconds};console.log('MUSIC',id,seconds.toFixed(1));m.dispose?.();
}
const old=fs.existsSync(path.join(root,'manifest.json'))?JSON.parse(fs.readFileSync(path.join(root,'manifest.json'))):{};
fs.writeFileSync(path.join(root,'manifest.json'),JSON.stringify({...manifest,sfx:{...old.sfx,...manifest.sfx},music:{...old.music,...manifest.music}},null,2));
