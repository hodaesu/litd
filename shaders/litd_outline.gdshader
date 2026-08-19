shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled;

// Optional inverted-hull outline. Use only where the game camera needs it;
// the Art Bible prioritizes clean silhouettes over thick comic contours.
uniform vec4 outline_color : source_color = vec4(0.018, 0.016, 0.018, 1.0);
uniform float outline_width : hint_range(0.0, 0.04) = 0.008;

void vertex() {
    VERTEX += NORMAL * outline_width;
}

void fragment() {
    ALBEDO = outline_color.rgb;
}
