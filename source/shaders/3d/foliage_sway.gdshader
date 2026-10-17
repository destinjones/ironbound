shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Trees, palms, reeds, bushes and grass of the desert scatter bending in the wind
// (source/match/environment/Wind.gd swaps it in for their flat-coloured materials). The
// bend grows with the square of the height above the model's base, so roots stay put; gusts
// roll across the map as a slow wave along the wind, with a quicker flutter on top.

uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness = 0.85;
uniform float metallic = 0.0;
uniform float specular = 0.5;
uniform vec2 wind = vec2(3.0, 0.0); // m/s on the world XZ plane, from Atmosphere
uniform float bend = 0.1; // m the top moves in a 5 m/s wind
uniform float height = 1.0; // m from the base to the top of the model
uniform float flutter = 1.6; // Hz

void vertex()
{
  vec3 origin = MODEL_MATRIX[3].xyz;
  float speed = length(wind);
  vec2 along = speed > 0.01 ? wind / speed : vec2(1.0, 0.0);
  float rise = clamp(VERTEX.y / height, 0.0, 1.2);
  float gust = 0.55 + 0.45 * sin(dot(origin.xz, along) * 0.12 - TIME * 1.1);
  float shake = sin(TIME * flutter * 6.2831853 + dot(origin.xz, vec2(0.71, 0.37))) * 0.3;
  vec2 offset = along * (gust + shake * gust) * bend * (speed / 5.0) * rise * rise;
  VERTEX += inverse(mat3(MODEL_MATRIX)) * vec3(offset.x, 0.0, offset.y);
}

void fragment()
{
  ALBEDO = albedo.rgb;
  ROUGHNESS = roughness;
  METALLIC = metallic;
  SPECULAR = specular;
}
