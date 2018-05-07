#version 420
#extension GL_EXT_gpu_shader4 : enable

// Attributes passed on from the vertex shader
smooth in vec3 WSVertexPosition;
smooth in vec3 WSVertexNormal;
smooth in vec2 WSTexCoord;

in vec3 localPos;
// Structure for holding light parameters
struct LightInfo {
    vec4 Position; // Light position in eye coords.
    vec3 La; // Ambient light intensity
    vec3 Ld; // Diffuse light intensity
    vec3 Ls; // Specular light intensity
};

// We'll have a single light in the scene with some default values
uniform LightInfo Light = LightInfo(
            vec4(2.0, 2.0, 10.0, 1.0),   // position
            vec3(0.2, 0.2, 0.2),        // La
            vec3(1.0, 1.0, 1.0),        // Ld
            vec3(0.2, 0.2, 0.2)         // Ls
            );

// This is no longer a built-in variable
out vec4 FragColor;


uniform vec3 diffusetest; //Kd
uniform vec3 ambienttest; //Ka
uniform vec3 speculartest; //Ks
uniform float shininesstest;

//---------------------------------------------------------------------------------------------
//Noise algorithm from:
//https://thebookofshaders.com/13/
//---------------------------------------------------------------------------------------------
float random (in vec2 st) {
    return fract(sin(dot(st.xy,
                         vec2(12.9898,78.233)))*
        43758.5453123);
}

// Based on Morgan McGuire @morgan3d
// https://www.shadertoy.com/view/4dS3Wd
float noise (in vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);

    // Four corners in 2D of a tile
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x) +
            (c - a)* u.y * (1.0 - u.x) +
            (d - b) * u.x * u.y;
}

#define OCTAVES 6
float fbm (in vec2 st) {
    // Initial values
    float value = 0.0;
    float amplitude = .5;
    float frequency = 0.;
    //
    // Loop of octaves
    for (int i = 0; i < OCTAVES; i++) {
        value += amplitude * noise(st);
        st *= 2.;
        amplitude *= .5;
    }
    return value;
}
//---------------------------------------------------------------------------------------------
//const vec2 invAtan = vec2(0.5191,0.3183);
//// function to take the seam away
//vec2 sphericalTex(vec3 p)
//{
//    vec2 uv  = vec2(atan(p.z, p.x), asin(p.y));
//    uv *= invAtan;
//    uv += 0.5;

//    return uv;
//}

//---------------------------------------------------------------------------------------------
// Noise for smaller random dots
//Modified from/Noise algorithm from:
//https://thebookofshaders.com/11/
//---------------------------------------------------------------------------------------------
float randomPerlin (in vec2 st) {
    return fract(sin(dot(st.xy,
                         vec2(0.170,0.220))) //0.310,0.250
                 * 43758.993);
}
// 2D Noise based on Morgan McGuire @morgan3d
// https://www.shadertoy.com/view/4dS3Wd
float noisePerlin (in vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);

    // Four corners in 2D of a tile
    float a = randomPerlin(i);
    float b = randomPerlin(i + vec2(1.0, 0.0));
    float c = randomPerlin(i + vec2(0.0, 1.0));
    float d = randomPerlin(i + vec2(1.0, 1.0));

    // Smooth Interpolation

    // Cubic Hermine Curve.  Same as SmoothStep()
    vec2 u = f*f*(3.0-2.0*f);
    // u = smoothstep(0.,1.,f);

    // Mix 4 coorners porcentages
    return mix(a, b, u.x) +
            (c - a)* u.y * (1.0 - u.x) +
            (d - b) * u.x * u.y;
}
//---------------------------------------------------------------------------------------------

void main() {
    // Calculate the normal (this is the expensive bit in Phong)
    vec3 n = normalize( WSVertexNormal );

    // Calculate the light vector
    vec3 s = normalize( vec3(Light.Position) - WSVertexPosition );

    // Calculate the view vector
    vec3 v = normalize(vec3(-WSVertexPosition));

    // Reflect the light about the surface normal
    vec3 r = reflect( -s, n );

    // Compute the light from the ambient, diffuse and specular components
    vec3 lightColor = (
            Light.La * ambienttest +
            Light.Ld * diffusetest * max( dot(s, n), 0.0 ) +
            Light.Ls * speculartest * pow( max( dot(r,v), 0.0 ), shininesstest ));


//    vec2 newUv = sphericalTex(vec3(WSTexCoord,1.0));
    //vec2 st = WSTexCoord.xy/WSVertexPosition.xy;
    //st.x *= WSTexCoord.x/WSTexCoord.y;

//    vec3 colorDots = vec3(0.0);
//    colorDots += fbmDots(WSTexCoord*1000.0);

    float p = noisePerlin(WSTexCoord*100.0);
    p = smoothstep(0.01, 0.022, p);

    vec3 color = vec3(0.465,0.258,0.082);
    color += fbm(WSTexCoord*5.0)*lightColor; //3.0

    FragColor = vec4(color*vec3(p),1.0);

}




//-------------MARBLE-SHADER-TEST----------------------------
//https://thebookofshaders.com/edit.php?log=161128210559
//float random (in vec2 st) {
//    return fract(sin(dot(st.xy,
//                         vec2(12.9898,78.233)))*
//        43758.5453123);
//}

//// Based on Morgan McGuire @morgan3d
//// https://www.shadertoy.com/view/4dS3Wd
//float noise (in vec2 st) {
//    vec2 i = floor(st);
//    vec2 f = fract(st);

//    // Four corners in 2D of a tile
//    float a = random(i);
//    float b = random(i + vec2(1.0, 0.0));
//    float c = random(i + vec2(0.0, 1.0));
//    float d = random(i + vec2(1.0, 1.0));

//    vec2 u = f * f * (3.0 - 2.0 * f);

//    return mix(a, b, u.x) +
//            (c - a)* u.y * (1.0 - u.x) +
//            (d - b) * u.x * u.y;
//}

//#define OCTAVES 6
//float fbm (in vec2 st) {
//    // Initial values
//    float value = 0.0;
//    float amplitud = .5;
//    float frequency = 0.;
//    //
//    // Loop of octaves
//    for (int i = 0; i < OCTAVES; i++) {
//        value += amplitud * noise(st);
//        st *= 2.;
//        amplitud *= .5;
//    }
//    return value;
//}

//float edge(float v, float center, float edge0, float edge1) {
//    return 1.0 - smoothstep(edge0, edge1, abs(v - center));
//}

//void main() {
////    vec2 st = gl_FragCoord.xy / u_resolution.xy;
////    st.x *= u_resolution.x / u_resolution.y;


//    float v0 = edge(fbm(WSTexCoord * 18.0), 0.5, 0.0, 0.2);
//    float v1 = smoothstep(0.5, 0.51, fbm(WSTexCoord * 14.0));
//    float v2 = edge(fbm(WSTexCoord * 14.0), 0.5, 0.0, 0.170);
//    float v3 = edge(fbm(WSTexCoord * 14.0), 0.5, 0.0, 0.122);

//    vec3 col = vec3(1.000,0.969,0.794);
//    col -= v0 * 0.230;
//    col = mix(col, vec3(0.970,0.794,0.609), v1);
//    col = mix(col, vec3(0.510,0.443,0.366), v2);
//    col -= v3 * 0.2;

//    FragColor = vec4(col,1.0);
//}
//------------------------------------------------------


//smaller dots - maybe use later
//float randomDots (in vec2 st) {
//    return fract(sin(dot(st.xy,
//                         vec2(0.760,0.290)))*
//        43758.233);
//}

//// Based on Morgan McGuire @morgan3d
//// https://www.shadertoy.com/view/4dS3Wd
//float noiseDots (in vec2 st) {
//    vec2 i = floor(st);
//    vec2 f = fract(st);

//    // Four corners in 2D of a tile
//    float a = randomDots(i);
//    float b = randomDots(i + vec2(1.0, 0.0));
//    float c = randomDots(i + vec2(0.0, 1.0));
//    float d = randomDots(i + vec2(1.0, 1.0));

//    vec2 u = f * f * (3.0 - 2.0 * f);

//    return mix(a, b, u.x) +
//            (c - a)* u.y * (1.0 - u.x) +
//            (d - b) * u.x * u.y;
//}

//#define OCTAVES 6
//float fbmDots (in vec2 st) {
//    // Initial values
//    float value = 0.2;
//    float amplitude = .7; //.5
//    float frequency = 0.;
//    //
//    // Loop of octaves
//    for (int i = 0; i < OCTAVES; i++) {
//        value += amplitude * noiseDots(st);
//        st *= 2.;
//        amplitude *= .2; //.5
//    }
//    return value;
//}
