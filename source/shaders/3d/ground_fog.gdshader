shader_type spatial;
render_mode unshaded, fog_disabled, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled;

// Full-screen pass that lays drifting banks of ground fog over the match. Like the cloud
// shadows it rebuilds each pixel's world position from the depth buffer, so the fog lies on
// terrain, props, units and buildings alike. It thins out with height: roofs and treetops
// stand out of a bank while what is on the ground sinks into it.

uniform sampler2D noise_texture : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_texture : hint_depth_texture;
uniform float period = 150.0;
// two layers that drift at different speeds, so the banks change shape as they move
uniform vec2 offset = vec2(0.0);
uniform vec2 offset_fine = vec2(0.0);
uniform float coverage = 0.0;  // 0 no fog, 1 fog nearly everywhere
uniform float softness = 0.34;
uniform float density = 0.7;  // how much the thickest fog hides
uniform float top = 5.0;  // metres above the ground where a bank has thinned out
uniform vec3 fog_color : source_color = vec3(0.45, 0.48, 0.47);

#include "res://source/shaders/3d/depth_reconstruction.gdshaderinc"

void vertex()
{
  POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment()
{
  float depth = textureLod(depth_texture, SCREEN_UV, 0.0).x;
  vec3 world = depth_to_world(SCREEN_UV, depth, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);

  float value = texture(noise_texture, (world.xz - offset) / period).r * 0.7 +
      texture(noise_texture, (world.xz - offset_fine) / (period * 0.37) + vec2(0.37, 0.11)).r * 0.3;
  float threshold = 1.0 - coverage;
  float bank = smoothstep(threshold - softness * 0.5, threshold + softness, value);
  float low = 1.0 - smoothstep(0.0, top, world.y);
  ALBEDO = fog_color;
  ALPHA = depth_is_background(depth) ? 0.0 : bank * density * mix(0.3, 1.0, low);
}
