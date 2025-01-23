shader_type canvas_item;

uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 vignette_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);

void fragment() {
    // Start completely transparent by default
    COLOR = vec4(0.0, 0.0, 0.0, 0.0);

    // Calculate distance from center (normalized)
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(UV, center) * 2.0;  // Multiply by 2 to normalize the distance

    // Create edge-weighted vignette effect only if opacity is greater than 0
    if (vignette_opacity > 0.0) {
        // Adjust this power to control how quickly it fades from edge to center
        float edge_weight = pow(dist, 3.0);

        // Create smooth falloff
        float vignette = smoothstep(0.0, 1.0 + vignette_intensity, edge_weight);

        // Set the color with edge-based opacity
        COLOR = vec4(vignette_color.rgb, vignette * vignette_opacity);
    }
}