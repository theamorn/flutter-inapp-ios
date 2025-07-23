uniform vec2 iResolution;
uniform float iTime;
uniform float iDropletCount;
out vec4 fragColor;

// Rain droplet shader based on "Heartfelt" by Martijn Steinrucken
// Adapted for Flutter with realistic rain effects

#define S(a, b, t) smoothstep(a, b, t)

// Random functions from the sample
vec3 N13(float p) {
   vec3 p3 = fract(vec3(p) * vec3(.1031,.11369,.13787));
   p3 += dot(p3, p3.yzx + 19.19);
   return fract(vec3((p3.x + p3.y)*p3.z, (p3.x+p3.z)*p3.y, (p3.y+p3.z)*p3.x));
}

vec4 N14(float t) {
	return fract(sin(t*vec4(123., 1024., 1456., 264.))*vec4(6547., 345., 8799., 1564.));
}

float N(float t) {
    return fract(sin(t*12345.564)*7658.76);
}

float Saw(float b, float t) {
	return S(0., b, t)*S(1., b, t);
}

// Main rain layer function adapted from sample
vec2 DropLayer2(vec2 uv, float t) {
    vec2 UV = uv;
    
    uv.y -= t*0.75; // Changed += to -= to make rain fall downward
    vec2 a = vec2(6., 1.);
    vec2 grid = a*2.;
    vec2 id = floor(uv*grid);
    
    float colShift = N(id.x); 
    uv.y += colShift;
    
    id = floor(uv*grid);
    vec3 n = N13(id.x*35.2+id.y*2376.1);
    vec2 st = fract(uv*grid)-vec2(.5, 0);
    
    float x = n.x-.5;
    
    float y = UV.y*20.;
    float wiggle = sin(y+sin(y));
    x += wiggle*(.5-abs(x))*(n.z-.5);
    x *= .7;
    float ti = fract(t+n.z);
    y = (Saw(.85, ti)-.5)*.9+.5;
    vec2 p = vec2(x, y);
    
    float d = length((st-p)*a.yx);
    
    float mainDrop = S(.4, .0, d);
    
    float r = sqrt(S(1., y, st.y));
    float cd = abs(st.x-x);
    float trail = S(.23*r, .15*r*r, cd);
    float trailFront = S(-.02, .02, st.y-y);
    trail *= trailFront*r*r;
    
    y = UV.y;
    float trail2 = S(.2*r, .0, cd);
    float droplets = max(0., (sin(y*(1.-y)*120.)-st.y))*trail2*trailFront*n.z;
    y = fract(y*10.)+(st.y-.5);
    float dd = length(st-vec2(x, y));
    droplets = S(.3, 0., dd);
    float m = mainDrop+droplets*r*trailFront;
    
    return vec2(m, trail);
}

// Static droplets function from sample - balanced density
float StaticDrops(vec2 uv, float t) {
	uv *= 15.; // Increased from 10. to 15. for balanced droplet density
    
    vec2 id = floor(uv);
    uv = fract(uv)-.5;
    vec3 n = N13(id.x*107.45+id.y*3543.654);
    vec2 p = (n.xy-.5)*.7;
    float d = length(uv-p);
    
    float fade = Saw(.025, fract(t+n.z));
    float c = S(.3, 0., d)*fract(n.z*10.)*fade;
    return c;
}

// Combined drops function
vec2 Drops(vec2 uv, float t, float l0, float l1, float l2) {
    float s = StaticDrops(uv, t)*l0; 
    vec2 m1 = DropLayer2(uv, t)*l1;
    vec2 m2 = DropLayer2(uv*1.85, t)*l2;
    
    float c = s+m1.x+m2.x;
    c = S(.3, 1., c);
    
    return vec2(c, max(m1.y*l0, m2.y*l1));
}

void main() {
    vec2 uv = (gl_FragCoord.xy-.5*iResolution.xy) / iResolution.y;
    vec2 UV = gl_FragCoord.xy/iResolution.xy;
    
    float T = iTime;
    float t = T*.2;
    
    // Rain amount based on dropletCount parameter - increased for better visibility
    float rainAmount = iDropletCount * 0.04; // Increased from 0.025 to 0.04 for better visibility
    
    // Blur amounts for glass fog effect
    float maxBlur = mix(3., 6., rainAmount);
    float minBlur = 2.;
    
    // Scale the UV for better droplet distribution
    uv *= .7;
    
    // Different rain layers based on rain intensity - enhanced for visibility
    float staticDrops = S(-.5, 1., rainAmount)*1.0; // Increased from *0.8 to *1.0 for better visibility
    float layer1 = S(.15, .65, rainAmount) * 0.5; // Increased from *0.4 to *0.5 for better visibility
    float layer2 = S(-.1, .4, rainAmount) * 0.5; // Increased from *0.4 to *0.5 for better visibility
    
    // Generate the rain droplets
    vec2 c = Drops(uv, t, staticDrops, layer1, layer2);
    
    // Calculate normals for refraction (expensive but realistic)
    vec2 e = vec2(.001, 0.);
    float cx = Drops(uv+e, t, staticDrops, layer1, layer2).x;
    float cy = Drops(uv+e.yx, t, staticDrops, layer1, layer2).x;
    vec2 n = vec2(cx-c.x, cy-c.x);		// Surface normals
    
    // Create glass fog effect based on rain trails
    float focus = mix(maxBlur-c.y, minBlur, S(.1, .2, c.x));
    
    // Apply refraction distortion to UV
    vec2 refractedUV = UV + n;
    
    // Create realistic water color with glass fog effect
    vec3 waterColor = vec3(0.0);
    
    if (c.x > 0.0) {
        // Darker glass fog base color for better rain visibility
        vec3 fogColor = vec3(0.3, 0.35, 0.4);
        
        // Water droplet color with subtle blue tint on dark background
        vec3 dropletColor = vec3(0.4, 0.45, 0.5);
        
        // Mix fog and droplet colors
        waterColor = mix(fogColor, dropletColor, S(0.1, 0.8, c.x));
        
        // Add highlights and reflections
        float highlight = pow(c.x, 2.0) * 0.5;
        waterColor += vec3(highlight);
        
        // Glass fog intensity
        float fogIntensity = c.y * 0.3 + c.x * 0.2;
        waterColor *= (1.0 + fogIntensity);
    }
    
    // Calculate alpha for transparency - enhanced for visibility
    float alpha = (c.x + c.y * 0.5) * 0.6; // Increased from 0.5 to 0.6 for better visibility
    
    // Add subtle color variation
    float colorShift = sin(T*.2)*.1+.9;
    waterColor *= colorShift;
    
    // Output the final rain effect
    fragColor = vec4(waterColor, alpha);
}
