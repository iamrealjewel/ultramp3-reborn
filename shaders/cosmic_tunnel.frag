#version 460 core
#include <flutter/runtime_effect.glsl>
precision highp float;

// Clear audio-reactive tunnel: depth rings + radial spokes + star streaks.

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

float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / uResolution;
  vec2 p = (fragCoord - 0.5 * uResolution) / min(uResolution.x, uResolution.y);

  float t = uTime;
  float beat = clamp(uBeat, 0.0, 1.0);

  float bass = (uB0 + uB1 + uB2) / 3.0;
  float mid = (uB3 + uB4 + uB5 + uB6) / 4.0;
  float treble = (uB7 + uB8 + uB9) / 3.0;

  float r = length(p);
  float a = atan(p.y, p.x);
  float ang = (a + 3.14159265) / 6.2831853;

  // Forward movement into tunnel.
  float speed = 0.75 + bass * 1.1 + beat * 1.2;
  float depth = 1.0 / max(r, 0.03);
  float z = depth + t * speed;

  // Tunnel depth rings (perspective illusion).
  float ringWave = abs(fract(z * 0.18) - 0.5);
  float rings = smoothstep(0.50, 0.42, ringWave);
  rings *= smoothstep(0.95, 0.12, r);

  // Radial spokes to make tunnel shape obvious.
  float spokes = abs(sin((ang + z * 0.02) * 6.2831853 * 24.0));
  spokes = smoothstep(0.90, 0.995, spokes);
  spokes *= smoothstep(0.88, 0.10, r);

  // Audio-reactive core pulse.
  float core = smoothstep(0.24 + bass * 0.08, 0.0, r);
  core *= 0.35 + 0.65 * beat;

  // Star streaks flying through tunnel.
  float starField = 0.0;
  vec2 gridUv = vec2(ang * 72.0, z * 0.35);
  vec2 gid = floor(gridUv);
  vec2 gfr = fract(gridUv);
  float rnd = hash12(gid);
  if (rnd > 0.84) {
    float sx = 0.5 + (rnd - 0.92) * 7.0;
    float sy = fract(rnd * 13.7 + t * (1.2 + treble * 1.8));
    float d = length((gfr - vec2(sx, sy)) * vec2(1.8, 0.35));
    starField = smoothstep(0.15, 0.0, d);
  }

  // Neon palette.
  vec3 bg = vec3(0.010, 0.006, 0.018);
  vec3 cyan = vec3(0.18, 0.95, 1.00);
  vec3 magenta = vec3(1.00, 0.20, 0.78);
  vec3 violet = vec3(0.40, 0.35, 1.00);

  float hueMix = 0.5 + 0.5 * sin(t * 0.25 + ang * 6.2831853);
  vec3 tunnelCol = mix(cyan, magenta, hueMix);
  tunnelCol = mix(tunnelCol, violet, 0.35 + 0.35 * mid);

  vec3 col = bg;
  col += tunnelCol * rings * (0.35 + 0.9 * mid);
  col += tunnelCol * spokes * (0.20 + 0.55 * treble);
  col += vec3(1.0) * starField * (0.20 + 0.65 * treble);
  col += mix(magenta, cyan, 0.5 + 0.5 * sin(t * 0.8)) * core;

  // Vignette and center depth.
  float vignette = smoothstep(1.10, 0.18, r);
  col *= vignette;

  fragColor = vec4(col, 1.0);
}
