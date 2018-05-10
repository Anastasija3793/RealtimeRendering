#version 330 core
// The initial PBR code from Jon Macy: https://github.com/NCCA/PBR/tree/master/SimplePBR
// Modified / edited by Anastasija Belaka
// This code is based on code from here https://learnopengl.com/#!PBR/Lighting
layout (location =0) out vec4 fragColour;

in vec2 TexCoords;
in vec3 WorldPos;
in vec3 Normal;
in mat3 TBN;

// base colour for the sphere
const vec3 potatoBaseColor = vec3(0.465,0.258,0.082);

in vec3 localPos;

// material parameters
uniform vec3 albedo;
uniform float metallic;
uniform float roughness;
uniform float ao;

const ivec3 off = ivec3(-1,0,1);
const vec2 size = vec2(7.0,0.0);

// lights
const vec3 lightPosition = vec3(1,1,1);
const vec3 lightColor = vec3(300,300,300);

uniform vec3 camPos;

const float PI = 3.1415926535897932384626433832795;

//---------------------------------------------------------------------------------------------
// 3D Noise algorithm from (edited):
// https://www.shadertoy.com/view/4ddXW4
//---------------------------------------------------------------------------------------------
float random (float rnd) {
    return fract(sin(rnd)*
        43758.5453123);
}
float noise(vec3 x) {
        vec3 p = floor(x);
        vec3 f = fract(x);
        f = f * f * (3.0 - 2.0 * f);

        float n = p.x + p.y * 157.0 + 113.0 * p.z;
        return mix(
                        mix(mix(random(n + 0.0), random(n + 1.0), f.x),
                                        mix(random(n + 157.0), random(n + 158.0), f.x), f.y),
                        mix(mix(random(n + 113.0), random(n + 114.0), f.x),
                                        mix(random(n + 270.0), random(n + 271.0), f.x), f.y), f.z);
}

float fbm(vec3 p) {
        float f = 0.0;
        f = 0.5000 * noise(p);
        p *= 3.01;
        f += 0.2500 * noise(p);
        p *= 2.02;
        f += 0.1250 * noise(p);

        return f;
}
//---------------------------------------------------------------------------------------------
// Noise for smaller random dots
// Modified from/Noise algorithm from:
// https://thebookofshaders.com/11/
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
// Converting 2D to 3D (then we don't have a seam in the noise)
// Algorithm from:
// http://www.inear.se/2010/05/spherical-perlin-noise/
//---------------------------------------------------------------------------------------------
vec3 convert(float r, vec2 texture)
{
    float lat = TexCoords.y / r * PI - PI / 2;
    float lon = TexCoords.x / r * 2 * PI - PI;
    vec3 newP = vec3(cos(lat) * cos(lon),sin(lat),cos(lat) * sin(lon));
    return newP;
}

// ----------------------------------------------------------------------------
float DistributionGGX(vec3 N, vec3 H, float roughness)
{
    float a = roughness*roughness;
    float a2 = a*a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH*NdotH;

    float nom   = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;

    return nom / denom;
}
// ----------------------------------------------------------------------------
float GeometrySchlickGGX(float NdotV, float roughness)
{
    float r = (roughness + 1.0);
    float k = (r*r) / 8.0;

    float nom   = NdotV;
    float denom = NdotV * (1.0 - k) + k;

    return nom / denom;
}
// ----------------------------------------------------------------------------
float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness)
{
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2 = GeometrySchlickGGX(NdotV, roughness);
    float ggx1 = GeometrySchlickGGX(NdotL, roughness);

    return ggx1 * ggx2;
}
// ----------------------------------------------------------------------------
vec3 fresnelSchlick(float cosTheta, vec3 F0)
{
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}
//----------------------------------------------------------------------------
// From http://www.neilmendoza.com/glsl-rotation-about-an-arbitrary-axis/
//----------------------------------------------------------------------------
mat4 rotationMatrix(vec3 axis, float angle)
{
    //axis = normalize(axis);
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;
    return mat4(oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s,  0.0,
                oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s,  0.0,
                oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c,           0.0,
                0.0,                                0.0,                                0.0,                                1.0);
}

vec3 rotateVector(vec3 src, vec3 tgt, vec3 vec) {
    float angle = acos(dot(src,tgt));

    // Check for the case when src and tgt are the same vector, in which case
    // the cross product will be ill defined.
    if (angle == 0.0) {
        return vec;
    }
    vec3 axis = normalize(cross(src,tgt));
    mat4 R = rotationMatrix(axis,angle);

    // Rotate the vec by this rotation matrix
    vec4 _norm = R*vec4(vec,1.0);
    return _norm.xyz / _norm.w;
}

void main()
{
    vec3 N = normalize(Normal);
    vec3 V = normalize(camPos - WorldPos);
    vec3 R = reflect(-V, N);

    // creating a rough/bump surface (using noise)
    float f = noisePerlin(TexCoords*100.f);
    float s11 = f;
    float s01 = noisePerlin((TexCoords+off.xy)*400.f);
    float s21 = noisePerlin((TexCoords+off.zx)*400.f);
    float s10 = noisePerlin((TexCoords+off.yx)*400.f);
    float s12 = noisePerlin((TexCoords+off.yz)*400.f);

    vec3 va = normalize(vec3(size.xy,s21-s01));
    vec3 vb = normalize(vec3(size.yx,s12-s10));
    vec4 bump = vec4( cross(va,vb), s11 );

    vec3 tgt = normalize(bump.rgb);

    // The source is just up in the Z-direction
    vec3 src = vec3(0.0, 0.0, 1.0);

    // Perturb the normal according to the target
    N = rotateVector(src, tgt, Normal);

    vec3 myColor = albedo;

    // making sure there is no seam
    vec3 seamless = convert(1.0,TexCoords);
    float base = fbm(seamless);

    // creating small dots (using noise with smoothstep)
    float dots = noisePerlin(TexCoords*100.0);
    dots = smoothstep(0.001, 0.052, dots);

    // creating bigger spots (using same noise with smoothstep)
    float spots = noisePerlin(TexCoords*15.0);
    spots = smoothstep(0.01, 0.12, spots);

    // mixing base colour and noise (with no seam)
    vec3 colorBase =  potatoBaseColor*2.0;
    colorBase = mix(vec3(0),colorBase, base);

    // mixing base noise with small dots and big spots
    myColor = mix(vec3(0.121, 0.082, 0.019),colorBase,dots*spots);
    float myRoughness = roughness;
    // calculate reflectance at normal incidence; if dia-electric (like plastic) use F0
    // of 0.04 and if it's a metal, use their albedo color as F0 (metallic workflow)
    vec3 F0 = vec3(0.03);
    F0 = mix(F0, myColor, metallic);

    // reflectance equation
    vec3 Lo = vec3(0.0);

        // calculate per-light radiance
        vec3 L = normalize(lightPosition - WorldPos);
        vec3 H = normalize(V + L);
        float distance = length(lightPosition - WorldPos);
        float attenuation = 1.0 / (distance * distance);
        vec3 radiance = lightColor * attenuation;

        // Cook-Torrance BRDF
        float NDF = DistributionGGX(N, H, myRoughness);
        float G   = GeometrySmith(N, V, L, myRoughness);
        vec3 F    = fresnelSchlick(max(dot(H, V), 0.0), F0);

        vec3 nominator    = NDF * G * F;
        float denominator = 4 * max(dot(V, N), 0.0) * max(dot(L, N), 0.0) + 0.001; // 0.001 to prevent divide by zero.
        vec3 brdf = nominator / denominator;

        // kS is equal to Fresnel
        vec3 kS = F;
        // for energy conservation, the diffuse and specular light can't
        // be above 1.0 (unless the surface emits light); to preserve this
        // relationship the diffuse component (kD) should equal 1.0 - kS.
        vec3 kD = vec3(1.0) - kS;
        // multiply kD by the inverse metalness such that only non-metals
        // have diffuse lighting, or a linear blend if partly metal (pure metals
        // have no diffuse light).
        kD *= 1.0 - metallic;

        // scale light by NdotL
        float NdotL = max(dot(N, L), 0.0);

        // add to outgoing radiance Lo
        Lo += (kD * myColor / PI + brdf) * radiance * NdotL;  // note that we already multiplied the BRDF by the Fresnel (kS) so we won't multiply by kS again

    // ambient lighting (note that the next IBL tutorial will replace
    // this ambient lighting with environment lighting).
    vec3 ambient = vec3(0.03) * myColor * ao;

    vec3 color = ambient + Lo;

    // HDR tonemapping
    color = color / (color + vec3(1.0));
    // gamma correct
    color = pow(color, vec3(1.0/1.1)); //2.2

    fragColour = vec4(color, 1.0);
}
