shader_type spatial;
render_mode cull_disabled;

// Townsfolk walking about a city (source/match/environment/CityLife.gd): one MultiMesh
// instance each. Legs and arms swing in this shader, so the script only moves and turns
// them. Per vertex: UV.x which part (0 leg, 0.25 arm, 0.5 robe, 0.75 head, 1 scarf),
// UV.y which side (0 left, 1 right); UV, not COLOR, as vertex colours may be read as sRGB. Per
// instance: INSTANCE_CUSTOM.r the step cycle (0..1), .g the gait (0 standing, 0.5 walking, 1
// running), .b the robe colour, .a the scarf colour, both as an index / 8 into the palettes below.

const float HIP_Y = 0.15;
const float SHOULDER_Y = 0.255;

uniform vec3 robes[8] : source_color;
uniform vec3 scarves[8] : source_color;
uniform vec3 trousers : source_color = vec3(0.22, 0.2, 0.18);
uniform vec3 skin_light : source_color = vec3(0.72, 0.53, 0.38);
uniform vec3 skin_dark : source_color = vec3(0.42, 0.29, 0.2);

varying vec3 v_color;

vec3 swing(vec3 v, float pivot, float angle)
{
  vec2 yz = vec2(v.y - pivot, v.z);
  float c = cos(angle);
  float s = sin(angle);
  return vec3(v.x, pivot + yz.x * c - yz.y * s, yz.x * s + yz.y * c);
}

void vertex()
{
  int part = int(round(UV.x * 4.0));
  float side = UV.y * 2.0 - 1.0;
  float cycle = INSTANCE_CUSTOM.r * 6.2831853;
  float gait = INSTANCE_CUSTOM.g;
  float stride = min(gait * 2.0, 1.0);
  if (part == 0)
  {
    VERTEX =
        swing(VERTEX, HIP_Y, sin(cycle + side * 1.5707963) * 0.55 * stride * (1.0 + 0.5 * gait));
  }
  else if (part == 1)
  {
    VERTEX = swing(
        VERTEX, SHOULDER_Y, -sin(cycle + side * 1.5707963) * 0.5 * stride * (1.0 + 0.5 * gait));
  }
  // lean into a run, and bob twice a cycle
  VERTEX.z += VERTEX.y * 0.25 * max(gait - 0.5, 0.0);
  VERTEX.y += abs(sin(cycle)) * 0.012 * stride;
  int robe = int(INSTANCE_CUSTOM.b * 8.0 + 0.5) % 8;
  int scarf = int(INSTANCE_CUSTOM.a * 8.0 + 0.5) % 8;
  vec3 skin =
      mix(skin_light, skin_dark, fract(INSTANCE_CUSTOM.b * 37.0 + INSTANCE_CUSTOM.a * 11.0));
  v_color = part == 0 ? trousers
      : part == 1     ? robes[robe] * 0.9
      : part == 2     ? robes[robe]
      : part == 3     ? skin
                      : scarves[scarf];
}

void fragment()
{
  ALBEDO = v_color;
  ROUGHNESS = 0.9;
}
