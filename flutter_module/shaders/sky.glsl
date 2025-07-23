uniform vec2 iResolution;
uniform float iTime;
out vec4 fragColor;

// Simple sky shader with floating clouds

// Simple noise function
float hash(vec2 p) {
    float h = dot(p, vec2(127.1, 311.7));
    return fract(sin(h) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    return mix(
        mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
        mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
        u.y
    );
}

// Simple cloud function
float clouds(vec2 uv) {
    vec2 cloudUV = uv * 3.0;
    cloudUV.x += iTime * 0.2; // Slow drift
    
    float cloud1 = noise(cloudUV);
    float cloud2 = noise(cloudUV * 2.0 + vec2(10.0, 20.0)) * 0.5;
    float cloud3 = noise(cloudUV * 4.0 + vec2(30.0, 40.0)) * 0.25;
    
    float cloudValue = cloud1 + cloud2 + cloud3;
    
    // Create fluffy cloud shapes
    cloudValue = smoothstep(0.5, 0.8, cloudValue);
    
    return cloudValue;
}

void main() {
    vec2 uv = gl_FragCoord.xy / iResolution.xy;
    
    // Simple sky gradient - blue at top, lighter at bottom
    vec3 skyColor = mix(vec3(0.5, 0.8, 1.0), vec3(0.8, 0.9, 1.0), uv.y);
    
    // Add some clouds
    float cloudMask = clouds(uv);
    vec3 cloudColor = vec3(1.0, 1.0, 1.0); // White clouds
    
    // Mix sky and clouds
    vec3 finalColor = mix(skyColor, cloudColor, cloudMask * 0.8);
    
    fragColor = vec4(finalColor, 1.0);
}
