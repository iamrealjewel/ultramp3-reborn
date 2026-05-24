#version 460 core
#include <flutter/runtime_effect.glsl>
precision highp float;

// Inspired by reference: new visualizers/images.steamusercontent.jpg

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

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 345.45));
  p += dot(p, p + 34.345);
  return fract(p.x * p.y);
}

vec3 rainbow(float t) {
  float r = 0.55 + 0.45 * sin(6.2831853 * (t + 0.00));
  float g = 0.55 + 0.45 * sin(6.2831853 * (t + 0.33));
  float b = 0.55 + 0.45 * sin(6.2831853 * (t + 0.66));
  return vec3(r, g, b);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 res = uResolution;
  vec2 uv = fragCoord / res;
  float beat = clamp(uBeat, 0.0, 1.0);

  // Background.
  vec2 p = (fragCoord - 0.5 * res) / min(res.x, res.y);
  float vign = smoothstep(1.10, 0.25, length(p));
  float mist = 0.015 * sin(uv.y * 10.0 + uTime * 0.5) +
      0.015 * sin(uv.x * 8.0 - uTime * 0.35);
  vec3 bg = vec3((0.02 + mist) * vign);

  // Mirror split.
  float midY = 0.52;
  float isRef = step(midY, uv.y);
  float y = (uv.y < midY) ? uv.y / midY : (1.0 - uv.y) / (1.0 - midY);

  // Columns.
  float cols = 96.0;
  float xCell = uv.x * cols;
  float cellId = floor(xCell);
  float cellX = fract(xCell);

  float bi = mod(floor(cellId / (cols / 10.0)), 10.0);
  float nextBi = mod(bi + 1.0, 10.0);
  float withinBand = fract(cellId / (cols / 10.0));
  float b = mix(bandAt(bi), bandAt(nextBi), withinBand);

  float jitter = (hash21(vec2(cellId, 0.0)) - 0.5) * 0.10;
  b = clamp(b * (1.0 + 0.55 * beat) + jitter, 0.0, 1.0);

  float height = 0.10 + 0.80 * b;
  float blocks = 22.0;
  float blockY = floor(y * blocks);
  float lit = step(blockY / blocks, height);

  float edgeX = smoothstep(0.0, 0.06, cellX) * smoothstep(0.0, 0.06, 1.0 - cellX);
  float cellMask = edgeX;

  vec3 col = rainbow(uv.x);
  col = pow(col, vec3(1.15));

  float glow = smoothstep(height + 0.18, height, y) * (0.55 + 0.45 * beat);
  glow *= 0.65 * cellMask;

  vec3 outCol = bg;
  outCol += col * (lit * 0.95 * cellMask);
  outCol += col * glow;

  if (isRef > 0.5) {
    float fade = smoothstep(1.0, 0.0, (uv.y - midY) / (1.0 - midY));
    outCol *= 0.10 + 0.60 * fade;
  }

  outCol *= 0.92 + 0.08 * sin(uv.y * res.y * 0.5);
  outCol *= 0.45 + 0.55 * vign;

  fragColor = vec4(outCol, 1.0);
}
