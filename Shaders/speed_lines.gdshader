shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 line_color : source_color = vec4(0.0, 0.8, 1.0, 0.6); // Cyber Cyan
uniform float line_count = 100.0;
uniform float inner_radius : hint_range(0.0, 1.0) = 0.25;

void fragment() {
    vec2 center = vec2(0.5);
    vec2 dir = UV - center;
    float dist = length(dir);
    
    // Convert to polar angle
    float angle = atan(dir.y, dir.x);
    
    // Generate radial line pattern based on noise/sine waves
    float lines = sin(angle * line_count + TIME * 40.0) * 0.5 + 0.5;
    lines = step(0.65, lines); // Sharpen lines
    
    // Smooth radial mask (keep center clean, show lines on outer edges)
    float mask = smoothstep(inner_radius, 0.5, dist);
    
    // Final output alpha controlled by intensity uniform
    float alpha = lines * mask * intensity * line_color.a;
    
    COLOR = vec4(line_color.rgb, alpha);
}