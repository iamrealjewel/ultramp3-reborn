#version 460 core
#include <flutter/runtime_effect.glsl>
precision highp float;

// Retro neon tunnel (best-effort).

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

  float r = length(p);
  float a = atan(p.y, p.x);
  float t = uTime;
  float beat = clamp(uBeat, 0.0, 1.0);

  float bass = (uB0 + uB1 + uB2) / 3.0;
  float treble = (uB7 + uB8 + uB9) / 3.0;

  float z = 1.0 / (r + 0.02);
  float speed = t * (0.8 + beat * 1.2 + bass * 0.8);
  float u = a / 6.2831853 + 0.05 * sin(z * 0.1 + t * 0.2);
  float v = z + speed;

  float grid = 0.0;
  grid += smoothstep(0.02, 0.0, abs(fract(u * 18.0) - 0.5) - 0.48);
  grid += smoothstep(0.02, 0.0, abs(fract(v * 2.5) - 0.5) - 0.48);
  grid = clamp(grid, 0.0, 1.0);

  vec3 col = mix(vec3(0.02, 0.00, 0.05), vec3(0.45, 0.85, 1.0), 0.35 + 0.65 * treble);
  col *= grid * (0.35 + 0.65 * smoothstep(0.0, 0.6, z));

  // Stars.
  float n = fract(sin(dot(uv * 500.0, vec2(12.9898, 78.233))) * 43758.5453);
  col += vec3(n) * 0.06 * smoothstep(0.2, 1.0, n);

  // Center glow.
  float center = smoothstep(0.7, 0.0, r);
  col += vec3(1.0, 0.2, 0.8) * center * (0.08 + 0.18 * beat);

  fragColor = vec4(col, 1.0);
}
