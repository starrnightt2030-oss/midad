// Atheer Live Scenes Engine — شيدر المشهد الحي.
//
// يرسم صورة الخلفية بنفس تحويل BoxFit.cover، ويطبّق حتى ٤ مؤثرات موضعية.
// كل مؤثر مربوط بقناة من صورة القناع (R/G/B/A) ومحصور داخلها فقط،
// فتبقى المباني والصخور والأثاث (القناع = 0) ثابتة تمامًا بدون أي تشوّه.
//
// أنواع المؤثرات (uType):
//   0 بدون، 1 تموج مياه هادئة، 2 تدفق (نهر/شلال)، 3 انجراف سحب،
//   4 توهج (فوانيس/شموع/نوافذ)، 5 ضباب/بخار، 6 تمايل نبات،
//   7 شفق قطبي، 8 تلألؤ نجوم، 9 أمواج بحر، 10 أشعة ضوء.
#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;   // مقاس الرسم (بكسل منطقي)
uniform vec2 uImg;    // مقاس الصورة الأصلية
uniform vec2 uFocus;  // نقطة المحاذاة عند القص (0..1)
uniform float uTime;  // ثوانٍ
uniform float uLevel; // شدة المؤثرات حسب وضع الجودة (0..1)
uniform float uDim;   // سطوع عام (وضع النوم يخفّضه تدريجيًا)
uniform vec4 uType;
uniform vec4 uSpeed;
uniform vec4 uAmount;
uniform vec4 uScale;
uniform vec4 uDirX;
uniform vec4 uDirY;
uniform vec4 uSel0;   // اختيار قناة القناع لكل مؤثر (one-hot)
uniform vec4 uSel1;
uniform vec4 uSel2;
uniform vec4 uSel3;
uniform sampler2D uImage;
uniform sampler2D uMask;

out vec4 fragColor;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
             mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 3; i++) {
    v += a * noise(p);
    p = p * 2.03 + 17.1;
    a *= 0.5;
  }
  return v;
}

// يحسب إزاحة إحداثيات العيّنة لمؤثر واحد (المؤثرات اللونية تُحسب لاحقًا).
vec2 displace(float type, float m, float spd, float amt, float scl, vec2 dir, vec2 uv, float t) {
  if (m < 0.004) return vec2(0.0);
  vec2 d = vec2(0.0);
  if (type == 1.0) {
    // مياه ساكنة: تموجات أفقية دقيقة تكبر كلما اقتربت من المشاهد (منظور).
    float persp = mix(0.35, 1.25, clamp(uv.y, 0.0, 1.0));
    float w = fbm(vec2(uv.x * 5.0 * scl, uv.y * 38.0 * scl / persp - t * spd * 0.6));
    float phase = uv.y * 150.0 * scl / persp - t * spd * 2.2 + w * 7.0;
    d.x = sin(phase) * amt * persp * (0.55 + 0.45 * w);
    d.y = (noise(vec2(uv.x * 9.0 * scl, uv.y * 70.0 * scl - t * spd)) - 0.5) * amt * 0.45 * persp;
  } else if (type == 2.0) {
    // تدفق في اتجاه dir: ضوضاء تنساب مع الزمن.
    vec2 p = uv * 7.0 * scl - dir * t * spd;
    d = (vec2(fbm(p), fbm(p + 5.2)) - 0.5) * amt;
    d += dir * (noise(p * 2.7) - 0.5) * amt * 1.4;
  } else if (type == 3.0) {
    // سحب: التفاف بطيء جدًا للمجال يجعل الحواف تتنفّس وتنجرف.
    vec2 p = uv * 2.5 * scl + dir * t * spd;
    d = (vec2(fbm(p), fbm(p + 9.1)) - 0.5) * amt;
    d += dir * sin(t * spd * 0.9 + uv.y * 4.0) * amt * 0.35;
  } else if (type == 5.0) {
    vec2 p = uv * 3.0 * scl + dir * t * spd;
    d = (vec2(fbm(p), fbm(p + 3.3)) - 0.5) * 0.004;
  } else if (type == 6.0) {
    // تمايل: إزاحة جانبية ناعمة متأخرة الطور حسب الارتفاع والمكان.
    float ph = t * spd + uv.y * 6.0 * scl + noise(uv * 4.0 * scl) * 6.2831;
    d.x = sin(ph) * amt + (noise(vec2(t * spd * 0.35, uv.y * 3.0)) - 0.5) * amt * 0.8;
    d.y = cos(ph * 0.7) * amt * 0.25;
  } else if (type == 7.0) {
    float ph = uv.x * 5.0 * scl + t * spd;
    d.y = sin(ph) * amt + (fbm(vec2(uv.x * 3.0 * scl - t * spd * 0.4, t * 0.05)) - 0.5) * amt * 1.5;
    d.x = (noise(vec2(uv.y * 4.0, t * spd * 0.3)) - 0.5) * amt * 0.6;
  } else if (type == 9.0) {
    // أمواج تتقدّم نحو الشاطئ (اتجاه dir) مع تفاوت في الطور.
    float persp = mix(0.4, 1.3, clamp(uv.y, 0.0, 1.0));
    float w = fbm(uv * vec2(3.0, 9.0) * scl);
    float ph = dot(uv, dir) * 60.0 * scl / persp - t * spd + w * 5.0;
    d.y = sin(ph) * amt * persp;
    d.x = (fbm(uv * vec2(6.0, 20.0) * scl + vec2(t * spd * 0.05, 0.0)) - 0.5) * amt * persp;
  }
  return d * m;
}

float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

// تعديل لوني: يرجع (كسب سطوع، لمعان مضاف، ضباب مضاف).
vec3 shade(float type, float m, float spd, float amt, float scl, vec2 dir, vec2 uv, float t, vec3 col, vec2 px) {
  if (m < 0.004) return vec3(0.0);
  float L = lum(col);
  if (type == 1.0 || type == 2.0 || type == 9.0) {
    // بريق على الانعكاسات المضيئة فقط (القمر، الشمس، الفوانيس).
    float g = noise(vec2(uv.x * 90.0 * scl, uv.y * 260.0 * scl) + vec2(t * spd * 0.8, -t * spd * 1.6));
    float s = pow(g, 9.0) * smoothstep(0.35, 0.85, L) * 2.2;
    float foam = 0.0;
    if (type == 9.0) {
      float ph = dot(uv, dir) * 60.0 * scl - t * spd;
      foam = sin(ph) * 0.06 * smoothstep(0.45, 0.9, L);
    }
    if (type == 2.0) foam = (fbm(uv * 14.0 * scl - dir * t * spd * 2.0) - 0.5) * 0.12 * smoothstep(0.3, 0.8, L);
    return vec3(foam * m, s * m * amt * 60.0, 0.0);
  }
  if (type == 4.0) {
    // تنفّس بطيء + ارتعاش لهب خفيف جدًا (بدون ومضات).
    float br = 0.55 * sin(t * spd * 0.9) + 0.3 * (noise(vec2(t * spd * 2.3, uv.x * 4.0 + uv.y * 3.0)) - 0.5) * 2.0
             + 0.15 * sin(t * spd * 2.7 + uv.y * 9.0);
    return vec3(br * amt * m, 0.0, 0.0);
  }
  if (type == 5.0) {
    float f = fbm(uv * vec2(2.2, 5.0) * scl + dir * t * spd);
    f = smoothstep(0.38, 0.85, f);
    return vec3(0.0, 0.0, f * amt * m);
  }
  if (type == 7.0) {
    float band = sin(uv.x * 7.0 * scl - t * spd * 0.8 + fbm(uv * 3.0 + t * 0.03) * 3.0);
    return vec3(band * amt * 2.5 * m * smoothstep(0.08, 0.4, L), 0.0, 0.0);
  }
  if (type == 8.0) {
    // تلألؤ النجوم الموجودة في الصورة: نكشف النقاط اللامعة بمقارنتها بما حولها.
    vec2 o = 2.5 / uImg;
    // نأخذ أسطع جار: النجمة أسطع من كل ما حولها، أما حافة القمر أو السحابة فلها جار مضيء
    // فلا تتلألأ (حتى لا تظهر ومضات على الحواف).
    float around = max(max(lum(texture(uImage, px + vec2(o.x, 0.0)).rgb), lum(texture(uImage, px - vec2(o.x, 0.0)).rgb)),
                       max(lum(texture(uImage, px + vec2(0.0, o.y)).rgb), lum(texture(uImage, px - vec2(0.0, o.y)).rgb)));
    float star = smoothstep(0.05, 0.22, L - around);
    vec2 cell = floor(px * uImg / 3.0);
    float h = hash(cell);
    float tw = sin(t * spd * (0.6 + h * 1.4) + h * 6.2831);
    return vec3(star * tw * amt * m, 0.0, 0.0);
  }
  if (type == 10.0) {
    float r = sin(dot(uv, dir) * 18.0 * scl - t * spd) * 0.5 + 0.5;
    r *= 0.6 + 0.4 * noise(vec2(dot(uv, vec2(-dir.y, dir.x)) * 12.0 * scl, t * spd * 0.2));
    return vec3((r - 0.5) * amt * m, 0.0, 0.0);
  }
  return vec3(0.0);
}

float pickMask(vec4 mk, vec4 sel) { return dot(mk, sel); }

void main() {
  vec2 frag = FlutterFragCoord().xy;
  float s = max(uSize.x / uImg.x, uSize.y / uImg.y);
  vec2 shown = uImg * s;
  vec2 uv = (frag - (uSize - shown) * uFocus) / shown;
  uv = clamp(uv, 0.0, 1.0);
  float t = uTime;

  vec4 mk = texture(uMask, uv);
  float m0 = pickMask(mk, uSel0) * uLevel;
  float m1 = pickMask(mk, uSel1) * uLevel;
  float m2 = pickMask(mk, uSel2) * uLevel;
  float m3 = pickMask(mk, uSel3) * uLevel;

  vec2 d = displace(uType.x, m0, uSpeed.x, uAmount.x, uScale.x, vec2(uDirX.x, uDirY.x), uv, t)
         + displace(uType.y, m1, uSpeed.y, uAmount.y, uScale.y, vec2(uDirX.y, uDirY.y), uv, t)
         + displace(uType.z, m2, uSpeed.z, uAmount.z, uScale.z, vec2(uDirX.z, uDirY.z), uv, t)
         + displace(uType.w, m3, uSpeed.w, uAmount.w, uScale.w, vec2(uDirX.w, uDirY.w), uv, t);

  // لا نسحب بكسلات من منطقة ثابتة إلى داخل المنطقة المتحركة: نقيس القناع عند نقطة الوصول.
  if (dot(d, d) > 0.0) {
    vec4 mk2 = texture(uMask, clamp(uv + d, 0.0, 1.0));
    float here = max(max(m0, m1), max(m2, m3));
    float there = max(max(pickMask(mk2, uSel0), pickMask(mk2, uSel1)), max(pickMask(mk2, uSel2), pickMask(mk2, uSel3))) * uLevel;
    d *= clamp(there / max(here, 0.001), 0.0, 1.0);
  }
  vec2 suv = clamp(uv + d, 0.0, 1.0);
  vec3 col = texture(uImage, suv).rgb;

  vec3 fx = shade(uType.x, m0, uSpeed.x, uAmount.x, uScale.x, vec2(uDirX.x, uDirY.x), uv, t, col, suv)
          + shade(uType.y, m1, uSpeed.y, uAmount.y, uScale.y, vec2(uDirX.y, uDirY.y), uv, t, col, suv)
          + shade(uType.z, m2, uSpeed.z, uAmount.z, uScale.z, vec2(uDirX.z, uDirY.z), uv, t, col, suv)
          + shade(uType.w, m3, uSpeed.w, uAmount.w, uScale.w, vec2(uDirX.w, uDirY.w), uv, t, col, suv);

  col *= 1.0 + fx.x;
  col += fx.y * col * col;
  float fog = clamp(fx.z, 0.0, 0.7);
  col = 1.0 - (1.0 - col) * (1.0 - fog * vec3(0.82, 0.86, 0.92));
  col = clamp(col, 0.0, 1.0) * uDim;
  fragColor = vec4(col, 1.0);
}
