shader_type spatial;
render_mode cull_back, diffuse_toon, specular_disabled;

// Baseline LITD material for the visual vertical slice.
// Deliberately simple: broad value masses first, texture detail second.
uniform vec4 base_color : source_color = vec4(0.14, 0.14, 0.15, 1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap;
uniform bool use_albedo_texture = false;
uniform float texture_strength : hint_range(0.0, 1.0) = 0.35;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.82;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.0;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.18;
uniform float rim_tint : hint_range(0.0, 1.0) = 0.65;

void fragment() {
    vec3 color = base_color.rgb;
    if (use_albedo_texture) {
        vec3 painted = texture(albedo_texture, UV).rgb;
        color = mix(color, color * painted * 2.0, texture_strength);
    }
    ALBEDO = color;
    ROUGHNESS = roughness_value;
    METALLIC = metallic_value;
    RIM = rim_amount;
    RIM_TINT = rim_tint;
}
