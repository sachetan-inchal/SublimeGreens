shader_type canvas_item;

uniform float radius : hint_range(0.0, 0.5) = 0.48;
uniform float feather : hint_range(0.0, 0.05) = 0.01;
uniform vec4 border_color : source_color = vec4(0.1, 0.85, 1.0, 0.9);
uniform float border_thickness : hint_range(0.0, 0.05) = 0.015;

void fragment() {
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(UV, center);
    
    // Outside circular radius -> transparent
    if (dist > radius + border_thickness) {
        COLOR = vec4(0.0);
    } else if (dist > radius) {
        // Border ring
        float alpha = smoothstep(radius + border_thickness, radius + border_thickness - feather, dist);
        COLOR = mix(COLOR, border_color, 0.85);
        COLOR.a *= alpha;
    } else {
        // Inside terrain view
        COLOR = texture(TEXTURE, UV);
    }
}
