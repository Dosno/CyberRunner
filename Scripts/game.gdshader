shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float scanline_count : hint_range(0.0, 1080.0) = 320.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.08;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.35;

void fragment() {
    vec2 uv = SCREEN_UV;
    vec4 color = texture(SCREEN_TEXTURE, uv);
    
    // Scanlines
    float scanline = sin(uv.y * scanline_count * 3.14159) * scanline_intensity;
    color.rgb -= scanline;
    
    // Vignette (subtle darkened screen edges)
    float uv_vignette = uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
    float vignette = clamp(pow(16.0 * uv_vignette, 0.25), 0.0, 1.0);
    color.rgb *= mix(1.0 - vignette_intensity, 1.0, vignette);
    
    COLOR = color;
}