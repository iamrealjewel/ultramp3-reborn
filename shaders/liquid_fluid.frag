#version 460 core
#include <flutter/runtime_effect.glsl>
precision highp float;

// Flowing liquid warp.

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

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / uResolution;
  vec2 p = (fragCoord - 0.5 * uResolution) / min(uResolution.x, uResolution.y);

  float t = uTime;
  float beat = clamp(uBeat, 0.0, 1.0);

  float bass = (uB0 + uB1 + uB2) / 3.0;
  float mid = (uB3 + uB4 + uB5 + uB6) / 4.0;
  float treble = (uB7 + uB8 + uB9) / 3.0;

  vec2 q = p;
  q.x += 0.25 * sin(p.y * 3.5 + t * 0.8 + bass * 1.5);
  q.y += 0.25 * cos(p.x * 3.5 + t * 0.8 + mid * 1.5);

  vec2 r = p;
  r.x += 0.15 * sin(q.y * 5.0 - t * 0.4 + treble * 2.0);
  r.y += 0.15 * cos(q.x * 5.0 + t * 0.6 + bass * 2.0);

  float wave = sin(r.x * 4.0 + t * 1.0) + cos(r.y * 3.0 - t * 0.8);
  wave += 1.2 * sin((r.x + r.y) * 2.0 + t * (0.8 + beat));
  wave *= 0.5;

  vec3 base = vec3(0.02, 0.02, 0.03);
  vec3 c1 = vec3(0.0, 0.9, 1.0);
  vec3 c2 = vec3(1.0, 0.0, 0.8);
  vec3 c3 = vec3(1.0, 0.8, 0.1);

  float k = 0.5 + 0.5 * wave;
  vec3 col = mix(c1, c2, smoothstep(0.0, 1.0, k));
  col = mix(col, c3, smoothstep(0.55, 0.95, k));

  float glow = smoothstep(0.9, 0.2, length(p));
  glow *= (0.35 + 0.65 * (0.3 * bass + 0.5 * mid + 0.2 * treble));

  vec3 outCol = base + col * glow;
  outCol += col * (0.10 + 0.25 * beat) * (0.5 + 0.5 * sin(t + wave * 2.0));

  // Specks.
  float n = fract(sin(dot(uv * 420.0, vec2(12.9898, 78.233))) * 43758.5453);
  outCol += vec3(n) * 0.05 * smoothstep(0.6, 1.0, n) * (0.35 + 0.65 * treble);

  fragColor = vec4(outCol, 1.0);
}
