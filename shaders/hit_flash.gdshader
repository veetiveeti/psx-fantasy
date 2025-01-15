shader_type spatial;
render_mode unshaded;  // Removed blend_add

uniform float flash_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    // Very specifically red values for emission
    EMISSION = vec3(1.0, 0.0, 0.0) * flash_strength * 2.0;  // Pure red emission
    ALBEDO = vec3(1.0, 0.0, 0.0);  // Red base color
    ALPHA = flash_strength * 0.5;  // Control transparency
}