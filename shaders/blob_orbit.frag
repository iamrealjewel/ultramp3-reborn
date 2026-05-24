#version 460 core
#include <flutter/runtime_effect.glsl>
precision highp float;

// Inspired by reference: new visualizers/1_DRmdFnTdQ3a2OLc1edw58g.webp

uniform vec2 uResolution;
uniform float uTime;
uniform float uBeat;

uniform float uB0;
uniform float uB1;
uniform float uB2;
uniform float uB3;
uniform float uB4;
uniform float uB5;
uniform float uB6;
uniform float uB7;
uniform float uB8;
uniform float uB9;

out vec4 fragColor;

vec2 rot(vec2 p, float a) {
  float s = sin(a);
  float c = cos(a);
  return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

float softCircle(vec2 p, float r, float blur) {
  float d = length(p);
  return smoothstep(r + blur, r - blur, d);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 res = uResolution;
  vec2 uv = fragCoord / res;
  vec2 p = (fragCoord - 0.5 * res) / min(res.x, res.y);

  float beat = clamp(uBeat, 0.0, 1.0);
  float t = uTime;

  float n = fract(sin(dot(uv * 380.0, vec2(12.9898, 78.233))) * 43758.5453);
  vec3 bg = vec3(0.0) + 0.03 * n;
  float vign = smoothstep(1.25, 0.35, length(p));
  bg *= 0.45 + 0.55 * vign;

  float low = (uB0 + uB1 + uB2) / 3.0;
  float mid = (uB3 + uB4 + uB5 + uB6) / 4.0;
  float high = (uB7 + uB8 + uB9) / 3.0;

  low = clamp(low * (1.0 + 0.65 * beat), 0.0, 1.0);
  mid = clamp(mid * (1.0 + 0.45 * beat), 0.0, 1.0);
  high = clamp(high * (1.0 + 0.35 * beat), 0.0, 1.0);

  float coreR = 0.16 + 0.03 * low;
  float ringR = 0.22 + 0.05 * mid;

  float core = softCircle(p, coreR, 0.01);
  vec3 outCol = bg;
  outCol = mix(outCol, vec3(0.02, 0.02, 0.03), core);

  float petals = 0.0;
  vec3 petalCol = vec3(0.0);
  for (int i = 0; i < 5; i++) {
    float fi = float(i);
    float ang = t * (0.65 + 0.06 * fi) + fi * 1.25;
    vec2 pp = rot(p, -ang);
    pp.x -= ringR;

    float blob = softCircle(pp, 0.13 + 0.08 * mid, 0.06 + 0.03 * low);
    float colT = fract(0.20 * fi + 0.10 * sin(t * 0.3));
    vec3 c = vec3(
      0.55 + 0.45 * sin(6.2831 * (colT + 0.00)),
      0.55 + 0.45 * sin(6.2831 * (colT + 0.33)),
      0.55 + 0.45 * sin(6.2831 * (colT + 0.66))
    );
    c = pow(c, vec3(1.25));

    petals = max(petals, blob);
    petalCol += c * blob;
  }
  petalCol /= 2.2;

  float aa = atan(p.y, p.x);
  float ang01 = (aa + 3.14159265) / (2.0 * 3.14159265);
  float rays = smoothstep(0.94, 1.0, sin(ang01 * 120.0 * 6.2831 + t * 0.6));
  rays *= smoothstep(0.55, 0.22, length(p));

  float halo = smoothstep(0.65, 0.20, length(p));
  halo *= (0.18 + 0.22 * beat);

  outCol += petalCol * (0.55 * petals);
  outCol += petalCol * (0.20 * rays);
  outCol += petalCol * halo;

  fragColor = vec4(outCol, 1.0);
}
