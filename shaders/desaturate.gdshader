shader_type canvas_item;

uniform float desaturation : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 c = texture(TEXTURE, UV);
    float gray = dot(c.rgb, vec3(0.299, 0.587, 0.114));
    c.rgb = mix(c.rgb, vec3(gray), desaturation);
    COLOR = c;
}
