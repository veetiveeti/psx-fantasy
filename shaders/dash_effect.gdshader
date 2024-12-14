shader_type canvas_item;

uniform float speed : hint_range(0.0, 10.0) = 1.0;
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 0.5);  // Reduced alpha

void fragment() {
    vec2 center = vec2(0.5, 0.5);
    vec2 dir = UV - center;
    float angle = atan(dir.y, dir.x);

    // Thinner lines
    float wobble = sin(TIME * speed + angle * 2.0) * 6.02;  // Reduced wobble
    float lines = sin(angle * 20.0 + wobble);  // More lines
    lines = step(0.95, lines);  // Much thinner lines

    float dist = length(dir);

    // Only show at very edges (last 2% of screen)
    float edge_start = 0.48;  // Start fade at 96% of distance to edge
    float edge_end = 0.5;     // Full strength at edge
    float edge_mask = smoothstep(edge_start, edge_end, dist);

    COLOR = line_color;
    COLOR.a = lines * edge_mask * 0.1;  // Reduced overall opacity
}