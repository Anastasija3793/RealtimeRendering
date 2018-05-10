#version 420
#extension GL_EXT_gpu_shader4 : enable

// Attributes passed on from the vertex shader
smooth in vec3 WSVertexPosition;
smooth in vec3 WSVertexNormal;
smooth in vec2 WSTexCoord;

in vec3 localPos;
// First making lambert
// Then use oren nayar diffuse

// Structure for holding light parameters
struct LightInfo {
    vec3 Position; // Light position in eye coords.
    vec3 Ld; // Diffuse light intensity
};

// We'll have a single light in the scene with some default values
uniform LightInfo Light = LightInfo(
            vec3(2.0, 2.0, 10.0),   // position //vec4(2.0, 2.0, 10.0, 1.0)
            vec3(1, 0.941, 0.819)        // Ld
            );

//// The material properties of our object
//struct MaterialInfo {
//    vec3 Ka; // Ambient reflectivity
//    vec3 Kd; // Diffuse reflectivity
//    vec3 Ks; // Specular reflectivity
//    float Shininess; // Specular shininess factor
//};

//// The object has a material
//uniform MaterialInfo Material = MaterialInfo(
//            vec3(0.5,0.5,0.5),    // Ka
//            vec3(0.980, 0.819, 0.380),    // Kd
//            vec3(1.0, 1.0, 1.0),    // Ks
//            10.0                    // Shininess
//            );



float lambert(vec3 N, vec3 L)
{
  vec3 nrmN = normalize(N);
  vec3 nrmL = normalize(L);
  float result = dot(nrmN, nrmL);
  return max(result, 0.0);
}


// This is no longer a built-in variable
out vec4 FragColor;

//uniform vec3 lightPosition;
//uniform vec3 eyePosition;
//varying vec3 surfacePosition, surfaceNormal;

uniform vec3 viewerPos;

const float PI = 3.1415926535897932384626433832795;

//---------------------------------------------------------------------------------------------
// 3D Noise algorithm from:
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
    float lat = WSTexCoord.y / r * PI - PI / 2;
    float lon = WSTexCoord.x / r * 2 * PI - PI;
    vec3 newP = vec3(cos(lat) * cos(lon),sin(lat),cos(lat) * sin(lon));
    return newP;
}
//---------------------------------------------------------------------------------------------
// Oren-Nayar diffuse lighting model from:
// https://github.com/glslify/glsl-diffuse-oren-nayar/blob/master/index.glsl
//---------------------------------------------------------------------------------------------
float orenNayarDiffuse(
  vec3 lightDirection,
  vec3 viewDirection,
  vec3 surfaceNormal,
  float roughness,
  float albedo) {

  float LdotV = dot(lightDirection, viewDirection);
  float NdotL = dot(lightDirection, surfaceNormal);
  float NdotV = dot(surfaceNormal, viewDirection);

  float s = LdotV - NdotL * NdotV;
  float t = mix(1.0, max(NdotL, NdotV), step(0.0, s));

  float sigma2 = roughness * roughness;
  float A = 1.0 + sigma2 * (albedo / (sigma2 + 0.13) + 0.5 / (sigma2 + 0.33));
  float B = 0.45 * sigma2 / (sigma2 + 0.09);

  return albedo * max(0.0, NdotL) * (A + B * s / t) / PI;
}
//---------------------------------------------------------------------------------------------


float rndRough (in vec2 st) {
    return fract(sin(dot(st.xy,
                         vec2(0.170,0.220))) //0.310,0.250
                 * 43758.993);
}

// 2D Noise based on Morgan McGuire @morgan3d
// https://www.shadertoy.com/view/4dS3Wd
float noiseRough (in vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);

    // Four corners in 2D of a tile
    float a = rndRough(i);
    float b = rndRough(i + vec2(1.0, 0.0));
    float c = rndRough(i + vec2(0.0, 1.0));
    float d = rndRough(i + vec2(1.0, 1.0));

    // Smooth Interpolation

    // Cubic Hermine Curve.  Same as SmoothStep()
    vec2 u = f*f*(3.0-2.0*f);
    // u = smoothstep(0.,1.,f);

    // Mix 4 coorners porcentages
    return mix(a, b, u.x) +
            (c - a)* u.y * (1.0 - u.x) +
            (d - b) * u.x * u.y;
}

void main() {
    // Calculate the normal (this is the expensive bit in Phong)
    vec3 n = normalize( WSVertexNormal );

    // Calculate the light vector
    vec3 s = normalize( vec3(Light.Position) - WSVertexPosition );

    // Calculate the view vector
    vec3 v = normalize(vec3(-WSVertexPosition));

    // Reflect the light about the surface normal
    vec3 r = reflect( -s, n );


    //--------------------------OREN NAYAR--------------------------
    //Light and view geometry
    vec3 lightDirection = normalize(Light.Position - WSVertexPosition);
    vec3 viewDirection = normalize(viewerPos - WSVertexPosition);


    vec2 posR = vec2(WSVertexPosition*50.0); //2.656
    float rough = noiseRough(posR);

//    float deform = fbmR(WSVertexPosition.xy*3.0); //3.0

    //Compute diffuse light intensity
    float power = orenNayarDiffuse(
      lightDirection,
      viewDirection,
      n,
      0.8,
      0.8);

    vec3 lightColor = (Light.Ld*power) * lambert(WSVertexNormal, Light.Position);


    //float material = orenNayarDiffuse(Light.Position);
    //vec3 lightColor=vec3(material,1.0);
    vec3 seamless = convert(1.0,WSTexCoord);
    float base = fbm(seamless);

    float dots = noisePerlin(WSTexCoord*100.0);
    dots = smoothstep(0.01, 0.022, dots);

//    float white = noisePerlin(WSTexCoord*100.0);
//    white = smoothstep(0.01, 0.022, dots);

    //vec3 rough = vec3(power,power,power);
    vec3 color = vec3(0.465,0.258,0.082);
    //vec3 colorWhite = vec3(1.0,0.0,0.0);
    //colorWhite += white;
    color += base*dots; //3.0 or 5.0


    //FragColor = vec4(color*lightColor,1.0);
    FragColor = vec4(color*lightColor*1.7,1.0);

}
