#version 460 core
#include <flutter/runtime_effect.glsl>
precision highp float;

// Inspired by reference: new visualizers/dsadasdadas.png

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
  vec2 p = (fragCoord - 0.5 * res) / min(res.x, res.y);

  float r = length(p);
  float a = atan(p.y, p.x);
  float ang01 = (a + 3.14159265) / (2.0 * 3.14159265);

  float beat = clamp(uBeat, 0.0, 1.0);

  // Deep purple background with subtle speckle.
  float n = fract(sin(dot(uv * 300.0, vec2(12.9898, 78.233))) * 43758.5453);
  vec3 bg = vec3(0.03, 0.01, 0.06) + 0.03 * n;
  float vign = smoothstep(1.15, 0.30, r);
  bg *= 0.35 + 0.65 * vign;

  // Smooth band interpolation around the ring.
  float idxf = ang01 * 10.0;
  float idx = floor(idxf);
  float f = fract(idxf);
  float b0 = bandAt(idx);
  float b1 = bandAt(mod(idx + 1.0, 10.0));
  float b = mix(b0, b1, smoothstep(0.0, 1.0, f));
  b = clamp(b * (1.0 + 0.65 * beat), 0.0, 1.0);

  // Ring bars.
  float baseR = 0.42;
  float barH = 0.06 + 0.26 * b;

  // Many thin bars.
  float cell = fract(ang01 * 180.0);
  float barMask = smoothstep(0.12, 0.03, abs(cell - 0.5));
  float bar = smoothstep(baseR, baseR + barH, r) -
      smoothstep(baseR + barH, baseR + barH + 0.012, r);
  bar *= barMask;

  // Gradient around ring.
  float hue = ang01;
  vec3 col = vec3(
    0.55 + 0.45 * sin(6.2831 * (hue + 0.00)),
    0.55 + 0.45 * sin(6.2831 * (hue + 0.33)),
    0.55 + 0.45 * sin(6.2831 * (hue + 0.66))
  );

  float ringBand = smoothstep(baseR + 0.045, baseR, r) *
      smoothstep(baseR - 0.045, baseR, r);
  float glow = smoothstep(baseR + barH + 0.12, baseR - 0.02, r);

  vec3 outCol = bg;
  outCol += col * (0.35 * ringBand + 1.2 * bar);
  outCol += col * (0.18 * glow);

  // Center disc.
  float disc = smoothstep(0.16, 0.155, r);
  outCol = mix(outCol, vec3(0.02, 0.02, 0.03), disc);

  fragColor = vec4(outCol, 1.0);
}
