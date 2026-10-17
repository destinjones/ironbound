shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled,
    world_vertex_coords;

// Chimney smoke for the city (source/match/environment/CityLife.gd): every chimney is one
// MultiMesh instance of a column of puffs that all sit at the chimney top; the vertex shader
// lifts each puff, lets the wind lean the column over and turns the puff to face the camera,
// so the smoke costs no script time. Per vertex: UV is the corner of its puff, COLOR.r where
// it starts up the column, .g and .b sideways jitter, .a size jitter. Per instance:
// INSTANCE_CUSTOM.r a random seed, .g strength (0 = no smoke), .b soot (0 = pale wood
// smoke, 1 = dark workshop smoke).

uniform vec3 pale_color : source_color = vec3(0.8, 0.79, 0.77);
uniform vec3 soot_color : source_color = vec3(0.34, 0.32, 0.3);
uniform vec2 wind = vec2(2.0, 0.5); // m/s, from Atmosphere.get_wind
uniform float column_height = 3.0; // m at full strength
uniform float rise = 0.12; // of the column per second
uniform float lean = 0.32; // m sideways per m up, per m/s of wind

varying float v_alpha;
varying float v_soot;

void vertex()
{
  vec3 origin = MODEL_MATRIX[3].xyz;
  float seed = INSTANCE_CUSTOM.r;
  float strength = INSTANCE_CUSTOM.g;
  float h = fract(COLOR.r + TIME * rise + seed * 7.0);
  float up = h * column_height * mix(0.6, 1.0, strength);
  vec2 side = wind * lean * up * smoothstep(0.0, 0.5, h);
  vec3 center = origin + vec3(side.x, up, side.y);
  float wobble = TIME * 0.7 + seed * 13.0 + COLOR.r * 9.0;
  center.x += sin(wobble) * 0.18 * h + (COLOR.g - 0.5) * 0.12 * h;
  center.z += cos(wobble * 1.3) * 0.18 * h + (COLOR.b - 0.5) * 0.12 * h;
  float size = mix(0.2, 1.1, pow(h, 0.6)) * (0.75 + 0.5 * COLOR.a) * mix(0.55, 1.0, strength);
  vec3 right = INV_VIEW_MATRIX[0].xyz;
  vec3 camera_up = INV_VIEW_MATRIX[1].xyz;
  VERTEX = center + (right * (UV.x - 0.5) + camera_up * (UV.y - 0.5)) * size;
  v_alpha = smoothstep(0.0, 0.03, h) * (1.0 - smoothstep(0.3, 1.0, h)) * strength;
  v_soot = INSTANCE_CUSTOM.b * (1.0 - 0.5 * h); // soot thins out as it rises
}

void fragment()
{
  float d = length(UV * 2.0 - 1.0);
  ALBEDO = mix(pale_color, soot_color, v_soot);
  ALPHA = (1.0 - smoothstep(0.1, 1.0, d)) * v_alpha * mix(0.4, 0.55, v_soot);
}
