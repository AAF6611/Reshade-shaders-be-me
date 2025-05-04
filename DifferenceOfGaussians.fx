// Difference of Gaussians Shader for ReShade
// Based on original Gaussian shader by Ioxa, created by A.A.Fouzi
// i got help from Chat-GPT not gonna lie
// Version 1.0

#include "ReShadeUI.fxh"
#include "ReShade.fxh"

// === Settings ===

uniform int GaussianBlurRadius1 < __UNIFORM_SLIDER_INT1
    ui_min = 0; ui_max = 4;
    ui_label = "First Blur Radius";
> = 1;

uniform float GaussianBlurOffset1 < __UNIFORM_SLIDER_FLOAT1
    ui_min = 0.1; ui_max = 2.0;
    ui_label = "First Blur Offset";
> = 1.0;

uniform int GaussianBlurRadius2 < __UNIFORM_SLIDER_INT1
    ui_min = 0; ui_max = 4;
    ui_label = "Second Blur Radius";
> = 2;

uniform float GaussianBlurOffset2 < __UNIFORM_SLIDER_FLOAT1
    ui_min = 0.1; ui_max = 2.0;
    ui_label = "Second Blur Offset";
> = 1.0;

uniform float DoGStrength < __UNIFORM_SLIDER_FLOAT1
    ui_min = 0.0; ui_max = 2.0;
    ui_label = "DoG Blend Strength";
> = 1.0;

// === Intermediate Textures ===
texture Tex1 { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
sampler Sampler1 { Texture = Tex1; };

texture Tex2 { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
sampler Sampler2 { Texture = Tex2; };

texture Tex3 { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
sampler Sampler3 { Texture = Tex3; };

texture Tex4 { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
sampler Sampler4 { Texture = Tex4; };

// === Gaussian Blur Utility ===

float3 GaussianBlur(in float2 texcoord, int radius, float offset, bool horizontal, sampler2D source)
{
    // Define up to 18 sample points
    static const float offsetArr[18] = {
        0.0, 1.495, 3.489, 5.483, 7.476, 9.470, 11.464, 13.458,
        15.452, 17.446, 19.440, 21.434, 23.427, 25.421, 27.415,
        29.448, 31.445, 33.442
    };

    static const float weightArr[18] = {
        0.033245, 0.0659162, 0.0636706, 0.0598195, 0.0546643, 0.0485872,
        0.0420046, 0.0353207, 0.0288881, 0.0229808, 0.0177816, 0.0133823,
        0.009796, 0.0069747, 0.0048301, 0.0032535, 0.0021315, 0.0013583
    };

    float2 direction = horizontal ? float2(BUFFER_PIXEL_SIZE.x, 0.0) : float2(0.0, BUFFER_PIXEL_SIZE.y);
    float3 color = tex2D(source, texcoord).rgb * weightArr[0];

    for (int i = 1; i <= radius * 4 + 2; ++i)
    {
        float2 offsetDir = direction * offsetArr[i] * offset;
        color += tex2D(source, texcoord + offsetDir).rgb * weightArr[i];
        color += tex2D(source, texcoord - offsetDir).rgb * weightArr[i];
    }

    return color;
}

// === Passes ===

float4 Pass_Horizontal1(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    return float4(GaussianBlur(texcoord, GaussianBlurRadius1, GaussianBlurOffset1, true, ReShade::BackBuffer), 1.0);
}

float4 Pass_Vertical1(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    return float4(GaussianBlur(texcoord, GaussianBlurRadius1, GaussianBlurOffset1, false, Sampler1), 1.0);
}

float4 Pass_Horizontal2(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    return float4(GaussianBlur(texcoord, GaussianBlurRadius2, GaussianBlurOffset2, true, ReShade::BackBuffer), 1.0);
}

float4 Pass_Vertical2(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    return float4(GaussianBlur(texcoord, GaussianBlurRadius2, GaussianBlurOffset2, false, Sampler2), 1.0);
}

// === Final DoG Combine ===

float4 Pass_DoG(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 blur1 = tex2D(Sampler2, texcoord).rgb;
    float3 blur2 = tex2D(Sampler4, texcoord).rgb;
    float3 dog = abs(blur1 - blur2) * DoGStrength;

    float3 original = tex2D(ReShade::BackBuffer, texcoord).rgb;
    return float4(saturate(/*original*/ + dog), 1.0);
}

// === Technique ===

technique DoG_Effect
{
    pass H1
    {
        VertexShader = PostProcessVS;
        PixelShader = Pass_Horizontal1;
        RenderTarget = Tex1;
    }
    pass V1
    {
        VertexShader = PostProcessVS;
        PixelShader = Pass_Vertical1;
        RenderTarget = Tex3;
    }
    pass H2
    {
        VertexShader = PostProcessVS;
        PixelShader = Pass_Horizontal2;
        RenderTarget = Tex2;
    }
    pass V2
    {
        VertexShader = PostProcessVS;
        PixelShader = Pass_Vertical2;
        RenderTarget = Tex4;
    }
    pass Combine
    {
        VertexShader = PostProcessVS;
        PixelShader = Pass_DoG;
    }
}
