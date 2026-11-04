Shader "Custom/SH_Clouds"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
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

            float3 boundsPosition;
            float3 boundsSize;

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseMap_ST;
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
            float3 RaycastIntersectBox(float3 boxPosition, float3 boxSize, float3 rayPosition, float3 rayDir)
            {
                float3 bMin = boxPosition - boxSize;
                float3 bMax = boxPosition + boxSize;

                float3 t0 = (bMin - rayPosition) / rayDir;
                float3 t1 = (bMax - rayPosition) / rayDir;

                float3 tMin = min(t0, t1);
                float3 tMax = max(t0, t1);

                float minDistanceToBox = max(0, max3(tMin.x, tMin.y, tMin.z));
                float maxDistanceToBox = max(0, min3(tMax.x, tMax.y, tMax.z));

                // minDistanceToBox <= maxDistanceToBox means ray intersects with box
                //return float2(minDistanceToBox <= maxDistanceToBox, maxDistanceToBox); // temp
                return float3(minDistanceToBox <= maxDistanceToBox, minDistanceToBox, maxDistanceToBox);
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float depth = SampleSceneDepth(IN.texcoord); // non linear depth
                float3 WorldPos = ComputeWorldSpacePosition(IN.texcoord, depth, UNITY_MATRIX_I_VP); // reconstructs worldposition from depth

                float3 rayOrigin = GetCameraPositionWS();
                float3 rayDir = WorldPos - rayOrigin;

                float3 intersects = RaycastIntersectBox(boundsPosition, boundsSize, rayOrigin, rayDir);
 
                // early exit
                half4 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, IN.texcoord);
                if (!intersects.x)
                    return color;

                color += intersects.z;
                
                return color;
            }
            ENDHLSL
        }
    }
}
