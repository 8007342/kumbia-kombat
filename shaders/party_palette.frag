#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec4 uDestination;
uniform vec4 uSource;
uniform vec2 uTextureSize;
uniform vec3 uOutfitHue;
uniform sampler2D uAtlas;
out vec4 fragColor;

void main() {
  vec2 local = (FlutterFragCoord().xy - uDestination.xy) / uDestination.zw;
  // Explicit texel centers keep nearest-neighbor atlas sampling inside the cell.
  vec2 texel = floor(uSource.xy + clamp(local, 0.0, 1.0) * uSource.zw) + 0.5;
  texel = clamp(texel, uSource.xy + 0.5, uSource.xy + uSource.zw - 0.5);
  vec4 pixel = texture(uAtlas, texel / uTextureSize);
  if (pixel.a <= 0.0001) {
    fragColor = pixel;
    return;
  }
  vec3 rgb = pixel.rgb / pixel.a;
  // Reserved CLOTHING ranges reviewed against the actual ensemble sheets.
  // The source has saturated wine/plum and bright pink rather than only cool
  // purple. Separate gates keep the woman's less saturated plum hair unchanged.
  float cool = step(0.12, rgb.b) * step(rgb.b * 0.70, rgb.r)
      * step(rgb.r * 0.99, rgb.b) * step(rgb.b * 0.20, rgb.g)
      * step(rgb.g, rgb.b * 0.66);
  float plum = step(100.0 / 255.0, rgb.r) * step(rgb.b * 0.70, rgb.r)
      * step(rgb.r * 0.32, rgb.b) * step(rgb.g, rgb.b * 0.55)
      * step(12.0 / 255.0, rgb.b - rgb.g);
  float pink = step(180.0 / 255.0, rgb.r) * step(rgb.b * 0.70, rgb.r)
      * step(rgb.r * 0.32, rgb.b) * step(rgb.g, rgb.b * 0.86)
      * step(12.0 / 255.0, rgb.b - rgb.g);
  float mask = max(cool, max(plum, pink));
  float value = max(rgb.r, max(rgb.g, rgb.b));
  float minimum = min(rgb.r, min(rgb.g, rgb.b));
  float saturation = (value - minimum) / max(value, 0.0001);
  vec3 hue = uOutfitHue / max(uOutfitHue.r, max(uOutfitHue.g, uOutfitHue.b));
  // Preserve source shade value and saturation, then re-premultiply alpha.
  vec3 recolored = mix(vec3(value), hue * value, saturation);
  fragColor = vec4(mix(rgb, recolored, mask) * pixel.a, pixel.a);
}
