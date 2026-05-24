#version 460 core
#include <flutter/runtime_effect.glsl>
precision highp float;

// Inspired by reference: new visualizers/apps.*.jpg

uniform vec2 uResolution;
uniform float uTime;
uniform float uBeat;

// 10-band spectrum (0..1)
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
  vec2 uv = fragCoord / uResolution;
  vec2 p = (fragCoord - 0.5 * uResolution) / min(uResolution.x, uResolution.y);
  float r = length(p);
  float a = atan(p.y, p.x);

  float t = uTime;
  float beat = clamp(uBeat, 0.0, 1.0);

  // Background vignette + cheap noise.
  float vign = smoothstep(1.05, 0.25, r);
  vec3 bg = vec3(0.03, 0.02, 0.06) * (0.25 + 0.75 * vign);
  float n = fract(sin(dot(uv * 200.0, vec2(12.9898, 78.233))) * 43758.5453);
  bg += 0.02 * n;

  // Ring.
  float ringR = 0.42;
  float ringW = 0.035;
  float ring = smoothstep(ringR + ringW, ringR, r) *
      smoothstep(ringR - ringW, ringR, r);

  // Spectrum around ring.
  float ang01 = (a + 3.14159265) / (2.0 * 3.14159265);
  float idxf = ang01 * 10.0;
  float idx = floor(idxf);
  float f = fract(idxf);
  float b0 = bandAt(idx);
  float b1 = bandAt(mod(idx + 1.0, 10.0));
  float band = mix(b0, b1, smoothstep(0.0, 1.0, f));
  band = clamp(band * (1.0 + 0.8 * beat), 0.0, 1.0);

  float barH = 0.08 + band * 0.22;
  float cell = fract(ang01 * 120.0);
  float barMask = smoothstep(0.10, 0.02, abs(cell - 0.5));
  float bar = smoothstep(ringR, ringR + barH, r) -
      smoothstep(ringR + barH, ringR + barH + 0.01, r);
  bar *= barMask;

  // Color wheel.
  float hue = ang01 + 0.08 * sin(t * 0.4);
  vec3 col = vec3(
    0.55 + 0.45 * sin(6.2831 * (hue + 0.00)),
    0.55 + 0.45 * sin(6.2831 * (hue + 0.33)),
    0.55 + 0.45 * sin(6.2831 * (hue + 0.66))
  );

  float glow = smoothstep(ringR + barH + 0.08, ringR, r);
  vec3 ringCol = col * (0.25 + 1.25 * ring) + col * (1.8 * bar);
  ringCol += col * (0.25 * glow);

  // Central disc.
  float disc = smoothstep(0.16, 0.155, r);
  vec3 discCol = vec3(0.02, 0.02, 0.03) +
      0.08 * vec3(1.0, 0.4, 0.8) * (1.0 - smoothstep(0.0, 0.16, r));

  vec3 outCol = bg;
  outCol = mix(outCol, ringCol, clamp(ring + bar, 0.0, 1.0));
  outCol = mix(outCol, discCol, disc);

  fragColor = vec4(outCol, 1.0);
}
