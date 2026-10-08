shader_type spatial;
uniform vec4 team_color : source_color;
uniform vec4 shirt : source_color;
uniform vec4 shorts : source_color;
uniform vec4 shoe : source_color;
uniform vec4 sole : source_color;
uniform vec4 sock : source_color;
uniform vec4 strap : source_color;
uniform float pattern=0.0;
varying vec3 vCloth;
varying vec3 bind_pos;

float iwHash(vec3 p){ p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3)); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float iwNoise(vec3 x){ vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
  return mix(mix(mix(iwHash(i), iwHash(i + vec3(1,0,0)), f.x), mix(iwHash(i + vec3(0,1,0)), iwHash(i + vec3(1,1,0)), f.x), f.y),
             mix(mix(iwHash(i + vec3(0,0,1)), iwHash(i + vec3(1,0,1)), f.x), mix(iwHash(i + vec3(0,1,1)), iwHash(i + vec3(1,1,1)), f.x), f.y), f.z); }
float iwFbm(vec3 p){ return 0.56 * iwNoise(p) + 0.29 * iwNoise(p * 2.07 + 7.1) + 0.15 * iwNoise(p * 4.31 + 3.7); }
float iwBand(float x, float a, float b){ float w = max(fwidth(x) * 0.8, 1e-4); return smoothstep(a - w, a + w, x) - smoothstep(b - w, b + w, x); }
float iwHash2(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }
float iwAAw(float d){ return max(fwidth(d), 1e-5); }
// filled SDF (d < 0 inside) and stroke of half-width hw, both antialiased
float iwFill(float d){ float w = iwAAw(d); return 1.0 - smoothstep(-w, w, d); }
float iwStroke(float d, float hw){ float w = iwAAw(d); return 1.0 - smoothstep(hw - w, hw + w, abs(d)); }
// 1 while a pattern of spatial period P (same units as coord) is resolvable (>= ~3 px), fading to 0 when sub-pixel
float iwLod(float coord, float P){ float px = fwidth(coord) / P; return 1.0 - smoothstep(0.22, 0.55, px); }
// dashed stitch along s (period P, duty 0..1)
float iwDash(float s, float P, float duty){ float x = s / P; float f = fract(x); float w = min(max(fwidth(x), 1e-4) * 1.2, 0.3); return smoothstep(0.0, w, f) * (1.0 - smoothstep(duty - w, duty, f)); }
float iwSdBox(vec2 p, vec2 b, float r){ vec2 q = abs(p) - b + r; return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r; }
float iwSdSeg(vec2 p, vec2 a, vec2 b){ vec2 pa = p - a, ba = b - a; float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0); return length(pa - ba * h); }
float iwSmin(float a, float b, float k){ float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0); return mix(b, a, h) - k * h * (1.0 - h); }

       
  
float iwLum(vec3 c){ return dot(c, vec3(0.299, 0.587, 0.114)); }
vec3 iwContrast(vec3 c){ return iwLum(c) > 0.42 ? c * 0.74 : c * 1.55 + 0.05; }
// ---- tee fine creases: complements the sculpted fold field of character-outfit.js ------------------------
float iwTeeCrease(vec3 p, float th) {
  float ax = abs(p.x), h = 0.0;
  float side = pow(abs(sin(th * 6.2831)), 2.0);
  float wy = (p.y - 0.705) / 0.0105 + 0.6 * sin(th * 6.2831 * 9.0 + p.y * 40.0);
  h += 0.00032 * side * exp(-pow((p.y - 0.765) / 0.035, 2.0)) * (0.5 + 0.5 * sin(wy * 6.2831));
  vec2 q = vec2(ax - 0.114, p.y - 0.884);
  float r = length(q), ang = atan(q.y, -q.x);
  h += 0.00011 * sin(ang * 17.0 + 1.3 + (p.z > 0.0 ? 0.0 : 2.1) + 2.5 * iwNoise(vec3(ang * 3.0, r * 60.0, p.z * 20.0))) * exp(-pow(r / 0.045, 2.0)) * smoothstep(0.006, 0.02, r) * (0.4 + 0.6 * iwNoise(p * 90.0));
  h += 0.00028 * sin(th * 6.2831 * 23.0 + 2.0 * sin(th * 30.0)) * (1.0 - smoothstep(0.698, 0.726, p.y));
  return h;
}
// ---- tee graphics -------------------------------------------------------------------------------
float iwShirtPattern(vec3 p) {
  float ax = abs(p.x);
  float m = 0.0;
  if (pattern < 0.5) {            // ringer: no body pattern (trim + big emblem)
    m = 0.0;
  } else if (pattern < 1.5) {     // double pinstripe
    m = iwBand(p.y, 0.842, 0.852) + iwBand(p.y, 0.866, 0.876);
  } else if (pattern < 2.5) {     // raglan sleeves + side panel
    float sleeve = smoothstep(0.108, 0.115, ax) * step(0.86, p.y);
    m = max(sleeve, iwBand(ax, 0.098, 0.2) * step(p.y, 0.86) * step(0.74, p.y) * step(abs(p.z + 0.012), 0.05));
  } else {                         // chevron + hem band
    float y0 = 0.925 - 0.55 * ax;
    m = iwBand(p.y - y0, -0.022, 0.0) * step(0.0, p.z);
    m = max(m, iwBand(p.y, 0.726, 0.738));
  }
  return clamp(m, 0.0, 1.0);
}
// ---- outfit patterns 4+ (appended; 0–3 above stay byte-identical so saved looks keep their graphics) -------------
// collar rib / sleeve cuff colours per pattern
vec3 iwTrimCol() {
  float pat = floor(pattern + 0.5);
  if (pat < 0.5 || pat == 3.0) return team_color.rgb;
  if (pat < 2.5) return iwContrast(shirt.rgb);
  if (pat == 6.0) return shirt.rgb * 0.55;            // camo: dark olive rib
  if (pat == 7.0) return shirt.rgb;                   // dip-dye: undyed collar
  return team_color.rgb;                                    // breton, splatter, jersey, track
}
vec3 iwCuffCol() {
  float pat = floor(pattern + 0.5);
  if (pat < 0.5 || pat == 3.0) return team_color.rgb;
  if (pat < 2.5) return iwContrast(shirt.rgb);
  if (pat == 4.0 || pat == 5.0) return shirt.rgb;     // breton / splatter: plain cuff
  if (pat == 6.0) return shirt.rgb * 0.55;
  if (pat == 7.0) return team_color.rgb * 0.9;              // dip-dyed ends
  return team_color.rgb;                                    // jersey, track
}
// ink splat stamped on the (roughly cylindrical) torso/sleeve around surface point c: wobbly rim + satellite drops
float iwSplat3(vec3 p, vec3 c, float R, float seed) {
  vec3 d = p - c;
  vec3 n = normalize(vec3(c.x, 0.0, c.z + 0.012));
  vec3 u = normalize(cross(vec3(0.0, 1.0, 0.0), n));
  vec2 q = vec2(dot(d, u), d.y);
  float a = atan(q.y, q.x);
  float wob = 1.0 + 0.13 * sin(5.0 * a + seed) + 0.07 * sin(9.0 * a + seed * 2.3) + 0.04 * sin(15.0 * a + seed * 0.7);
  float sd = length(q) - R * wob;
  for (int k = 0; k < 4; k++) {
    float fk = float(k); float aa = seed * 1.7 + fk * 1.9;
    vec2 o = vec2(cos(aa), sin(aa)) * R * (1.28 + 0.4 * fract(fk * 0.37 + seed));
    sd = min(sd, length(q - o) - R * (0.08 + 0.07 * fract(fk * 0.71 + seed * 0.3)));
  }
  sd = max(sd, abs(dot(d, n)) - 0.045);            // stay on this side of the body
  return iwFill(sd);
}
// athletic block digit (seven segments, rounded); q in digit units (half-width 0.5, half-height 1); SDF in units
float iwDigitSD(vec2 q, int dgt) {
  const int SEG[10] = int[10](0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F);
  int bits = SEG[clamp(dgt, 0, 9)];
  float d = 1e3;
  if ((bits & 1) != 0) d = min(d, iwSdBox(q - vec2(0.0, 0.86), vec2(0.4, 0.14), 0.07));
  if ((bits & 2) != 0) d = min(d, iwSdBox(q - vec2(0.36, 0.44), vec2(0.14, 0.42), 0.07));
  if ((bits & 4) != 0) d = min(d, iwSdBox(q - vec2(0.36, -0.44), vec2(0.14, 0.42), 0.07));
  if ((bits & 8) != 0) d = min(d, iwSdBox(q - vec2(0.0, -0.86), vec2(0.4, 0.14), 0.07));
  if ((bits & 16) != 0) d = min(d, iwSdBox(q - vec2(-0.36, -0.44), vec2(0.14, 0.42), 0.07));
  if ((bits & 32) != 0) d = min(d, iwSdBox(q - vec2(-0.36, 0.44), vec2(0.14, 0.42), 0.07));
  if ((bits & 64) != 0) d = min(d, iwSdBox(q, vec2(0.36, 0.13), 0.07));
  return d;
}
/** Base colour of shirt-slot fragments (tee body = part 1, sleeves = part 2). */
vec3 iwShirtCol(vec3 p, vec2 uv, float part) {
  if (pattern < 3.5) return mix(shirt.rgb, team_color.rgb, iwShirtPattern(p));
  float pat = floor(pattern + 0.5);
  vec3 c = shirt.rgb;
  float ax = abs(p.x), zc = p.z + 0.012;
  if (pat == 4.0) {                        // BRETON: team stripes on the body and around the sleeves, plain yoke
    float sy, P, lo, hi;
    if (part < 1.5) { sy = p.y; P = 0.026; lo = 0.703; hi = 0.938; }
    else { sy = uv.y; P = 0.0235; lo = 0.036; hi = vCloth.z - 0.024; }
    float f = abs(fract((sy - lo) / P) - 0.5);
    float band = iwFill((f - 0.21) * P) * step(lo, sy) * step(sy, hi);
    float m = mix(0.42 * step(lo, sy) * step(sy, hi), band, iwLod(sy, P));
    c = mix(shirt.rgb, team_color.rgb, m);
  } else if (pat == 5.0) {                 // SPLATTER: team ink splats, drips and speckles on a dark tee
    float m = 0.0;
    m = max(m, iwSplat3(p, vec3(0.062, 0.93, 0.072), 0.042, 1.3));
    m = max(m, iwSplat3(p, vec3(-0.058, 0.768, 0.086), 0.025, 4.1));
    m = max(m, iwSplat3(p, vec3(-0.096, 0.952, -0.052), 0.04, 2.2));
    m = max(m, iwSplat3(p, vec3(0.03, 0.742, -0.088), 0.027, 5.7));
    m = max(m, iwSplat3(p, vec3(0.2, 0.872, 0.004), 0.028, 3.3));
    if (part < 1.5 && p.z > 0.0) {
      for (int k = 0; k < 3; k++) {
        float fk = float(k);
        float x0 = 0.04 + 0.019 * fk; float y1 = 0.905 - 0.018 * fk; float y0 = y1 - (0.07 + 0.04 * fract(fk * 0.618 + 0.3));
        float w = 0.0056 - 0.0012 * fk;
        float dd = iwSdSeg(vec2(p.x, p.y), vec2(x0, y0), vec2(x0, y1)) - w * mix(1.0, 0.7, (y1 - p.y) / (y1 - y0));
        dd = min(dd, length(vec2(p.x - x0, (p.y - y0) * 0.85)) - w * 1.5);
        m = max(m, iwFill(dd));
      }
    }
    vec3 cp = p * 75.0; vec3 cell = floor(cp); vec3 fr = fract(cp) - 0.5;
    float rnd = iwHash(cell);
    m = max(m, iwFill((length(fr) - 0.24 * rnd) / 75.0) * step(0.87, rnd) * iwLod(p.y * 75.0, 1.0));
    c = mix(shirt.rgb, team_color.rgb, m);
  } else if (pat == 6.0) {                 // SPLAT CAMO: sand + shadow blobs over olive, with a few team-ink patches
    vec3 q = p * vec3(15.0, 11.0, 15.0);
    float n1 = iwFbm(q + 3.1), n2 = iwFbm(q * 1.15 + 11.7), n3 = iwFbm(q * 0.85 + 27.3);
    c = mix(c, mix(shirt.rgb, vec3(0.8, 0.76, 0.62), 0.5), iwFill(0.585 - n2));
    c = mix(c, shirt.rgb * 0.5, iwFill(0.575 - n1));
    c = mix(c, team_color.rgb, iwFill(0.655 - n3));
  } else if (pat == 7.0) {                 // DIP-DYE: team dye soaked up from the hem with a bleeding waterline
    float wav = 0.011 * sin(uv.x * 6.2831 * 3.0 + 1.1) + 0.024 * (iwFbm(p * 26.0) - 0.5);
    vec3 pale = mix(team_color.rgb, shirt.rgb, 0.42);
    if (part < 1.5) {
      float line = 0.792 + wav;
      float k = 1.0 - smoothstep(line - 0.026, line + 0.004, p.y);
      c = mix(shirt.rgb, mix(pale, team_color.rgb * 0.92, 1.0 - smoothstep(0.7, line, p.y)), k);
      float streak = smoothstep(0.62, 0.9, iwNoise(vec3(p.x * 170.0, p.y * 7.0, p.z * 170.0))) * (1.0 - smoothstep(line, line + 0.04, p.y)) * step(line - 0.004, p.y);
      c = mix(c, mix(shirt.rgb, team_color.rgb, 0.3), streak * 0.65);
    } else {
      float L = vCloth.z;
      float k = smoothstep(L - 0.075 + wav, L - 0.035 + wav, uv.y);
      c = mix(shirt.rgb, mix(pale, team_color.rgb * 0.92, smoothstep(L - 0.05, L, uv.y)), k);
    }
  } else if (pat == 8.0) {                 // JERSEY: team side panels with white piping, V-neck insert, shoulder yoke
    if (part < 1.5) {
      float side = step(0.07, ax);
      float panel = iwFill(abs(zc) - 0.043) * side * step(p.y, 0.95);
      float pipe = iwStroke(abs(zc) - 0.043, 0.0017) * side * step(p.y, 0.95);
      float vneck = iwSdSeg(vec2(ax, p.y), vec2(0.056, 1.0), vec2(0.0, 0.93));
      float v = iwFill(vneck - 0.0085) * step(0.0, p.z);
      float vpipe = iwStroke(vneck - 0.0085, 0.0015) * step(0.0, p.z);
      float yoke = smoothstep(0.962, 0.966, p.y) * (1.0 - v);
      c = mix(c, team_color.rgb, max(max(panel, v), yoke));
      c = mix(c, vec3(0.96), max(pipe, vpipe));
    } else {
      float L = vCloth.z;
      float pipe = iwStroke(uv.y - (L - 0.03), 0.0016);
      c = mix(c, team_color.rgb, smoothstep(0.02, 0.024, uv.y) * (1.0 - smoothstep(0.034, 0.038, uv.y)));   // shoulder yoke continues
      c = mix(c, vec3(0.96), pipe);
    }
  } else {                                 // TRACK TOP: twin white stripes down the sides and sleeves, team yoke
    vec3 sc = vec3(0.95);
    if (part < 1.5) {
      float st = (iwStroke(zc - 0.0085, 0.0032) + iwStroke(zc + 0.0085, 0.0032)) * step(0.07, ax);
      float yoke = smoothstep(0.955, 0.959, p.y);
      c = mix(c, team_color.rgb, yoke);
      c = mix(c, sc, clamp(st, 0.0, 1.0));
      c = mix(c, sc, iwStroke(p.y - 0.957, 0.0014));
    } else {
      float dx = (fract(uv.x + 0.5) - 0.5) * 0.31;
      float st = iwStroke(dx - 0.0085, 0.0032) + iwStroke(dx + 0.0085, 0.0032);
      c = mix(c, team_color.rgb, 1.0 - smoothstep(0.03, 0.034, uv.y));
      c = mix(c, sc, clamp(st, 0.0, 1.0) * smoothstep(0.03, 0.034, uv.y));
    }
  }
  return c;
}

// squid badge: ink splat with a white squid glyph; returns (splat coverage, glyph coverage)
vec2 iwEmblem(vec2 q, float R) {
  float a = atan(q.y, q.x); float r = length(q);
  float wob = 1.0 + 0.1 * sin(5.0 * a + 0.6) + 0.06 * sin(9.0 * a + 2.1) + 0.035 * sin(14.0 * a + 1.0);
  float splat = r - R * wob;
  splat = min(splat, length(q - vec2(R * 1.18, R * 0.62)) - R * 0.13);
  splat = min(splat, length(q - vec2(-R * 1.12, -R * 0.7)) - R * 0.1);
  splat = min(splat, length(q - vec2(R * 0.5, -R * 1.22)) - R * 0.08);
  // glyph: one silhouette — arrowhead mantle with swept fins flowing into a tall body, low oval eyes, four tentacles
  vec2 g = q / R;
  float fins = max(abs(g.x) * 1.02 + (g.y - 0.7) * 0.95, -(g.y - 0.22));
  float body = iwSdBox(g - vec2(0.0, 0.06), vec2(0.17, 0.3), 0.15);
  float glyph = iwSmin(fins, body, 0.08);
  float tent = 1e3;
  for (int i = 0; i < 4; i++) {
    float fi = float(i) - 1.5;
    vec2 tq = g - vec2(fi * 0.1, -0.2);
    tq.x -= fi * 0.1 * smoothstep(0.0, -0.3, tq.y) + 0.03 * sin(tq.y * 13.0 + fi) * smoothstep(-0.05, -0.3, tq.y);
    float w = mix(0.052, 0.03, smoothstep(-0.02, -0.3, tq.y));
    tent = min(tent, iwSdBox(tq - vec2(0.0, -0.15), vec2(w, 0.15), 0.028));
  }
  glyph = iwSmin(glyph, tent, 0.05);
  vec2 e1 = (g - vec2(0.075, 0.0)) / vec2(0.04, 0.062), e2 = (g - vec2(-0.075, 0.0)) / vec2(0.04, 0.062);
  float eyes = (min(length(e1), length(e2)) - 1.0) * 0.04;
  glyph = max(glyph, -eyes);
  return vec2(iwFill(splat), iwFill(glyph * R));
}


void vertex(){vCloth=vec3(COLOR.g*32.0,0.0,COLOR.b);bind_pos=vec3(UV2,COLOR.r-.5);}

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
