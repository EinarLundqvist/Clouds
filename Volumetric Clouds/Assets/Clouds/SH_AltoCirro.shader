Shader "Custom/SH_Alto"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
        _Tiling ("Tiling", float) = 1.0
        _ScatteringStrength ("Scattering Strength", float) = 1.0
        _Scattering ("Scattering", Range(-1.0, 1.0)) = 0.6
    }

    SubShader
    {
        Tags { "RenderType" = "Transparent" "Queue" = "Transparent" "RenderPipeline" = "UniversalPipeline" }
        Blend SrcAlpha OneMinusSrcAlpha
        //ZTest Always
        ZWrite Off
        Cull Off

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
            };
 
            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseMap_ST;
                float _Tiling;
                float _ScatteringStrength;
                float _Scattering;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.positionWS = positionWS;
                OUT.positionHCS = TransformWorldToHClip(positionWS);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                return OUT;
            }

            //                    1 - g^2                    θ is the original trajectory 
            //  p(θ) = ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━        
            //         4π(1 + g^2 - 2g * cos(θ))^3/2                      ↓ scattering factor, between -1 & 1
            float HenyeyGreenstein(float3 lightDir, float3 viewDir, float g)
            {
                // dot(a, b) = a.x*b.x + a.y*b.y + a.z*b.z
                // which is geometricly
                // dot(a, b) = |a| * |b| * cos(θ)
                // since the vec3s are normalized its effectivly 1 * 1 * cos(θ)
                // dot(a, b) = cos(θ)
                float cosTheta = dot(lightDir, viewDir);

                static const float pi = 3.14159265358979323;
                const float g2 = g * g;
                return (1.0 / (4.0 * pi)) * ((1.0 - g2) / pow(1.0 + g2 - 2.0 * g * cosTheta, 1.5)) * _ScatteringStrength;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                Light mainLight = GetMainLight();
                float3 lightDir = mainLight.direction;
                float3 viewDir = IN.positionWS - GetCameraPositionWS();
                float HG = saturate(HenyeyGreenstein(lightDir, normalize(viewDir), _Scattering));

                float3 color = _BaseColor.rgb + mainLight.color * HG;
                float alpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.positionWS.xz * _Tiling * 0.00001).r;


                alpha *= _BaseColor.a;
                return float4(color, alpha);
            }
            ENDHLSL
        }
    }
}
 