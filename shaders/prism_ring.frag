#version 460 core
#include <flutter/runtime_effect.glsl>
precision highp float;

// Inspired by reference: new visualizers/maxresdefault2.jpg

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

float bandAt(float idx) {
  if (idx < 0.5) return uB0;
  if (idx < 1.5) return uB1;
  if (idx < 2.5) return uB2;
  if (idx < 3.5) return uB3;
  if (idx < 4.5) return uB4;
  if (idx < 5.5) return uB5;
  if (idx < 6.5) return uB6;
  if (idx < 7.5) return uB7;
  if (idx < 8.5) return uB8;
  return uB9;
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 res = uResolution;
  vec2 uv = fragCoord / res;

  // Perspective-ish coordinates.
  vec2 q = (fragCoord - 0.5 * res) / min(res.x, res.y);
  q.y *= 1.20;
  float r = length(q);
  float a = atan(q.y, q.x);
  float ang01 = (a + 3.14159265) / (2.0 * 3.14159265);

  float beat = clamp(uBeat, 0.0, 1.0);

  // Background glow: red left / blue right.
  float lr = (uv.x - 0.5);
  vec3 bg = vec3(0.0);
  bg += vec3(0.25, 0.05, 0.08) * smoothstep(-0.9, 0.2, -lr) * 0.40;
  bg += vec3(0.05, 0.10, 0.25) * smoothstep(-0.2, 0.9, lr) * 0.40;
  bg *= 0.55;

  // Band around ring.
  float idxf = ang01 * 10.0;
  float idx = floor(idxf);
  float f = fract(idxf);
  float b = mix(bandAt(idx), bandAt(mod(idx + 1.0, 10.0)), smoothstep(0.0, 1.0, f));
  b = clamp(b * (1.0 + 0.60 * beat), 0.0, 1.0);

  float baseR = 0.48;
  float thick = 0.040;
  float ring = smoothstep(baseR + thick, baseR, r) * smoothstep(baseR - thick, baseR, r);

  float segs = 80.0;
  float cell = fract(ang01 * segs);
  float segMask = smoothstep(0.48, 0.40, abs(cell - 0.5));

  float h = 0.05 + 0.28 * b;
  float outer = smoothstep(baseR, baseR + h, r);
  float inner = smoothstep(baseR - thick, baseR - thick - 0.015, r);
  float bar = outer * inner * segMask;

  float light = 0.35 + 0.65 * (0.5 + 0.5 * cos(a + 0.8));
  float side = smoothstep(-0.05, 0.05, q.x);
  vec3 sideCol = mix(vec3(1.0, 0.35, 0.45), vec3(0.45, 0.70, 1.0), side);
  vec3 col = sideCol * (0.75 + 0.25 * light);

  float halo = smoothstep(baseR + h + 0.22, baseR - 0.05, r);
  halo *= (0.35 + 0.65 * beat);

  vec3 outCol = bg;
  outCol += col * (ring * 0.25);
  outCol += col * (bar * 1.25);
  outCol += col * (halo * 0.22);

  outCol = outCol + 0.10 * outCol * outCol;

  fragColor = vec4(outCol, 1.0);
}
