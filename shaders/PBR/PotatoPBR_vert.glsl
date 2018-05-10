#version 410 core
// this demo is based on code from here https://learnopengl.com/#!PBR/Lighting
uniform mat4 MVP;
uniform mat4 MV;
uniform mat4 P;
uniform mat4 M;
uniform mat3 N;
/// @brief the vertex passed in
layout (location = 0) in vec3 inVert;
/// @brief the normal passed in
layout (location = 2) in vec3 inNormal;
/// @brief the in uv
layout (location = 1) in vec2 inUV;

out vec2 TexCoords;
out vec3 WorldPos;
out vec3 Normal;

out vec3 localPos;

//---------------------------------------------------------------------------------------------
// Noise for base shape
// Modified from/Noise algorithm from:
// https://thebookofshaders.com/11/
//---------------------------------------------------------------------------------------------
float random (in vec2 st) {
    return fract(sin(dot(st.xy,
                         vec2(0.170,0.220))) //0.310,0.250
                 * 43758.993);
}

// 2D Noise based on Morgan McGuire @morgan3d
// https://www.shadertoy.com/view/4dS3Wd
float noise (in vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);

    // Four corners in 2D of a tile
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

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
// Noise for smaller displacement
// Modified from/Noise algorithm from:
// https://thebookofshaders.com/13/
//---------------------------------------------------------------------------------------------
float randomSmaller (in vec2 st) {
    return fract(sin(dot(st.xy,
                         vec2(12.9898,78.233)))*
        43758.5453123);
}

// Based on Morgan McGuire @morgan3d
// https://www.shadertoy.com/view/4dS3Wd
float noiseSmaller (in vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);

    // Four corners in 2D of a tile
    float a = randomSmaller(i);
    float b = randomSmaller(i + vec2(1.0, 0.0));
    float c = randomSmaller(i + vec2(0.0, 1.0));
    float d = randomSmaller(i + vec2(1.0, 1.0));

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
        value += amplitude * noiseSmaller(st);
        st *= 1.6;
        amplitude *= .5;
    }
    return value;
}
//---------------------------------------------------------------------------------------------
void main()
{
    Normal = normalize(N * inNormal);
    //Normal = inNormal;

    // Compute the unprojected vertex position
    WorldPos = vec3(MV * vec4(inVert, 1.0) );

    // Copy across the texture coordinates
    TexCoords = inUV;

    // creating some smaller deformation
    float deform = fbm(inVert.xy*3.0);

    // creating main deformation for the shape
    vec2 pos = vec2(inVert*2.544);
    float n = noise(pos);

    // Compute the position of the vertex
    gl_Position = MVP * vec4(inNormal+inVert*(vec3(n)+deform),1.0);

    localPos = inVert;
}
