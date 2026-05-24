#version 460 core
#include <flutter/runtime_effect.glsl>
precision highp float;

// Glowing solar plasma rings.

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

  float bass = (uB0 + uB1) * 0.5;
  float mid = (uB2 + uB3 + uB4 + uB5) * 0.25;
  float treble = (uB6 + uB7 + uB8 + uB9) * 0.25;

  float coreRadius = 0.16 + bass * 0.08;
  float coreGlow = smoothstep(coreRadius + 0.15, coreRadius, r);

  float ringDist1 = abs(r - 0.32 - mid * 0.06);
  float ring1 = smoothstep(0.012, 0.0, ringDist1);
  float ringDist2 = abs(r - 0.44 - treble * 0.05);
  float ring2 = smoothstep(0.010, 0.0, ringDist2);

  float flare = 0.0;
  flare += pow(max(0.0, sin(a * 10.0 + t * 1.7)), 6.0) * (0.15 + 0.35 * treble);
  flare += pow(max(0.0, sin(a * 6.0 - t * 1.1)), 5.0) * (0.12 + 0.25 * mid);
  flare *= smoothstep(0.65, 0.25, r);

  vec3 bg = vec3(0.01, 0.00, 0.02);
  float n = fract(sin(dot(uv * 260.0, vec2(12.9898, 78.233))) * 43758.5453);
  bg += vec3(n) * 0.02;

  vec3 hot = vec3(1.0, 0.55, 0.10);
  vec3 mag = vec3(1.0, 0.10, 0.70);
  vec3 blu = vec3(0.20, 0.70, 1.00);

  vec3 col = bg;
  col += hot * coreGlow * (0.55 + 0.45 * beat);
  col += mag * ring1 * (0.55 + 0.75 * mid);
  col += blu * ring2 * (0.55 + 0.75 * treble);
  col += (hot + mag) * flare * (0.8 + 0.6 * beat);

  fragColor = vec4(col, 1.0);
}
