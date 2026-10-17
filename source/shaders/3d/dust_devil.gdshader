shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled,
    world_vertex_coords;

// A dust devil: one mesh of puffs that all sit at the node's origin; the vertex shader spins
// them up a widening funnel and turns each one to face the camera, so it costs no script
// time (source/match/environment/Wind.gd only moves the node). Per vertex: UV is the corner
// of its puff, COLOR.r where it starts up the column, .g its angle, .b and .a radius and
// size jitter.

uniform vec3 dust_color : source_color = vec3(0.74, 0.62, 0.47);
uniform float column_height = 6.0; // m
uniform float spin = 2.4; // rad/s at the foot, slower higher up
uniform float rise = 0.18; // of the column height per second
instance uniform float life = 1.0; // 0..1, fades the whole devil in and out

varying float v_alpha;

void vertex()
{
  vec3 origin = MODEL_MATRIX[3].xyz;
  float h = fract(COLOR.r + TIME * rise);
  float angle = COLOR.g * 6.2831853 + TIME * spin * (1.6 - h);
  float radius = mix(0.15, 2.6, pow(h, 1.8)) * (0.75 + 0.5 * COLOR.b);
  vec3 center = origin + vec3(cos(angle) * radius, h * column_height, sin(angle) * radius);
  center.x += sin(TIME * 0.9 + h * 3.0) * 0.5 * h; // the column wavers
  float size = mix(0.35, 1.8, h) * (0.7 + 0.6 * COLOR.a);
  vec3 right = INV_VIEW_MATRIX[0].xyz;
  vec3 up = INV_VIEW_MATRIX[1].xyz;
  VERTEX = center + (right * (UV.x - 0.5) + up * (UV.y - 0.5)) * size;
  v_alpha = smoothstep(0.0, 0.06, h) * (1.0 - smoothstep(0.5, 1.0, h)) * life;
}

void fragment()
{
  float d = length(UV * 2.0 - 1.0);
  ALBEDO = dust_color;
  ALPHA = (1.0 - smoothstep(0.15, 1.0, d)) * v_alpha * 0.5;
}
