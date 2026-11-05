Shader "Custom/SH_Clouds"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
        _Scattering ("Scattering", Range(-1, 1)) = 0
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        ZTest Always ZWrite Off Cull Off
        Pass
        {
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            float3 boundsPosition;
            float3 boundsSize;

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseMap_ST;
                float _Scattering;
            CBUFFER_END

            float max3(float m, float a, float x)
            {
                return max(m, max(a, x));
            }
            float min3(float m, float a, float x)
            {
                return min(m, min(a, x));
            }

            // https://jcgt.org/published/0007/03/04/paper.pdf
            // x is distance to box, y is max distance trough box
            float RaycastIntersectBox(float3 boxPosition, float3 boxSize, float3 rayPosition, float3 rayDir)
            {
                float3 bMin = boxPosition - boxSize;
                float3 bMax = boxPosition + boxSize;

                float3 t0 = (bMin - rayPosition) / rayDir;
                float3 t1 = (bMax - rayPosition) / rayDir;

                float3 tMin = min(t0, t1);
                float3 tMax = max(t0, t1);

                float minDistanceToBox = max(0, max3(tMin.x, tMin.y, tMin.z));
                float maxDistanceToBox = max(0, min3(tMax.x, tMax.y, tMax.z));

                // rayorigin + raydir * minDistanceToBox is the world position of entry point and
                // rayorigin + raydir * maxDistanceToBox is the world position of exit point
                // to get distance between points we can disregard the rayorigin + raydir since its offset is equal for both
                // and prevent the distance from dropping below 0, since nothing behind camera should be calculated.
                float distanceWithinBox = max(0, maxDistanceToBox - minDistanceToBox);

                // minDistanceToBox <= maxDistanceToBox means ray intersects with box
                return distanceWithinBox;
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
                return (1.0 / (4.0 * pi)) * ((1.0 - g2) / pow(1.0 + g2 - 2.0 * g * cosTheta, 1.5));
            }

            float SampleDensity(float3 worldPosition)
            {
                return 1;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float depth = SampleSceneDepth(IN.texcoord); // non linear depth
                float3 WorldPos = ComputeWorldSpacePosition(IN.texcoord, depth, UNITY_MATRIX_I_VP); // reconstructs worldposition from depth

                float3 rayOrigin = GetCameraPositionWS();
                float3 rayDir = normalize(WorldPos - rayOrigin);

                float distanceWithinBox = RaycastIntersectBox(boundsPosition, boundsSize, rayOrigin, rayDir);
 
                // Early exit if not intersecting with bounding box
                half4 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, IN.texcoord);
                if (distanceWithinBox == 0) // Ray dosent intersect with bouding box
                    return color;

                //                                                                     transmittance ↓      ↓ density
                // transmittance is light reaching camera that dosent get absorbed or scatterd away, T = e^-d.
                // beer's law adapted from https://advances.realtimerendering.com/s2015/The%20Real-time%20Volumetric%20Cloudscapes%20of%20Horizon%20-%20Zero%20Dawn%20-%20ARTR.pdf
                //float density = SampleDensity(distanceWithinBox);
                float beerLambert = exp(-distanceWithinBox);

                Light mainLight = GetMainLight();
                float3 lightDir = mainLight.direction; // WS direction from light to surface
                float HG = HenyeyGreenstein(lightDir, rayDir, _Scattering);

                float absoption = 1.0 - beerLambert;
                float3 scatter = mainLight.color * HG * absoption;
                color.rgb = color.rgb * beerLambert + scatter; // background attenuated + in-scattered light
                
                return color;
            }
            ENDHLSL
        }
    }
}
