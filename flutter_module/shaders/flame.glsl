uniform vec2 iResolution;
uniform float iTime;
out vec4 fragColor;

// Flame shader based on noise functions
float noise(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float smoothNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = noise(i);
    float b = noise(i + vec2(1.0, 0.0));
    float c = noise(i + vec2(0.0, 1.0));
    float d = noise(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for (int i = 0; i < 6; i++) {
        value += amplitude * smoothNoise(p * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    
    return value;
}

void main() {
    vec2 uv = gl_FragCoord.xy / iResolution.xy;
    
    // Create flame-like movement
    uv.x += sin(uv.y * 4.0 + iTime * 2.0) * 0.1;
    uv.y -= iTime * 0.3;
    
    // Generate noise for flame pattern
    float flame = fbm(uv * 4.0 + vec2(0.0, iTime * 2.0));
    flame += fbm(uv * 8.0 + vec2(iTime * 0.5, iTime * 3.0)) * 0.5;
    flame += fbm(uv * 16.0 + vec2(iTime * 1.5, iTime * 4.0)) * 0.25;
    
    // Create flame shape (stronger at bottom, weaker at top)
    float flameShape = 1.0 - smoothstep(0.0, 1.0, uv.y);
    flameShape *= smoothstep(0.0, 0.1, uv.x) * smoothstep(1.0, 0.9, uv.x);
    
    flame *= flameShape;
    flame = clamp(flame, 0.0, 1.0);
    
    // Create flame colors (red to yellow to orange)
    vec3 color1 = vec3(1.0, 0.0, 0.0);     // Red
    vec3 color2 = vec3(1.0, 0.5, 0.0);     // Orange
    vec3 color3 = vec3(1.0, 1.0, 0.0);     // Yellow
    vec3 color4 = vec3(0.0, 0.0, 0.0);     // Black
    
    vec3 flameColor;
    if (flame < 0.3) {
        flameColor = mix(color4, color1, flame / 0.3);
    } else if (flame < 0.6) {
        flameColor = mix(color1, color2, (flame - 0.3) / 0.3);
    } else {
        flameColor = mix(color2, color3, (flame - 0.6) / 0.4);
    }
    
    // Add some blue at the base for realistic flame
    if (uv.y < 0.2 && flame > 0.1) {
        flameColor = mix(flameColor, vec3(0.0, 0.5, 1.0), 0.3 * (0.2 - uv.y) * 5.0);
    }
    
    // Make the flame more intense
    flame = pow(flame, 0.8);
    
    fragColor = vec4(flameColor * flame, flame * 0.8);
}
