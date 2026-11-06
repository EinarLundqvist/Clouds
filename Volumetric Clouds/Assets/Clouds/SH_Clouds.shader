Shader "Custom/SH_Clouds"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
        _Scattering ("Scattering", Range(-1, 1)) = 0
        _StepLength ("Step Length", Range(0.05, 5)) = 1
        _MaxMarchDistance ("Max March Distance", float) = 50

        //Light marching
        _LightrayStepLength ("Lightray Length", Range(0.1, 5)) = 2.0
        _StepsTowardsLight ("Steps towards light", int) = 5
        _Blue("Blue", 2D) = "white"
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
            TEXTURE2D(_Blue);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseMap_ST;
                float _Scattering;
                float _MaxMarchDistance;
                float _StepLength;
                float _LightrayStepLength;
                float _StepsTowardsLight;
            CBUFFER_END

            float3 mod289(float3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
            float4 mod289(float4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
            float4 permute(float4 x) { return mod289(((x * 34.0) + 10.0) * x); }
            float4 taylorInvSqrt(float4 r) { return 1.79284291400159 - 0.85373472095314 * r; }

            float simplexNoise(float3 v)
            {
                const float2 C = float2(1.0 / 6.0, 1.0 / 3.0);
                const float4 D = float4(0.0, 0.5, 1.0, 2.0);
            
                // First corner
                float3 i  = floor(v + dot(v, C.yyy));
                float3 x0 = v - i + dot(i, C.xxx);
            
                // Other corners
                float3 g  = step(x0.yzx, x0.xyz);
                float3 l  = 1.0 - g;
                float3 i1 = min(g.xyz, l.zxy);
                float3 i2 = max(g.xyz, l.zxy);
            
                float3 x1 = x0 - i1 + C.xxx;
                float3 x2 = x0 - i2 + C.yyy;   // 2.0*C.x = 1/3 = C.y
                float3 x3 = x0 - D.yyy;        // -1.0 + 3.0*C.x = -0.5 = -D.y
            
                // Permutations
                i = mod289(i);
                float4 p = permute(permute(permute(
                             i.z + float4(0.0, i1.z, i2.z, 1.0))
                           + i.y + float4(0.0, i1.y, i2.y, 1.0))
                           + i.x + float4(0.0, i1.x, i2.x, 1.0));
                
                // Gradients: 7x7 points over a square, mapped onto an octahedron
                float  n_ = 0.142857142857;    // 1.0 / 7.0
                float3 ns = n_ * D.wyz - D.xzx;
                
                float4 j  = p - 49.0 * floor(p * ns.z * ns.z);
                
                float4 x_ = floor(j * ns.z);
                float4 y_ = floor(j - 7.0 * x_);
                
                float4 x = x_ * ns.x + ns.yyyy;
                float4 y = y_ * ns.x + ns.yyyy;
                float4 h = 1.0 - abs(x) - abs(y);
                
                float4 b0 = float4(x.xy, y.xy);
                float4 b1 = float4(x.zw, y.zw);
                
                float4 s0 = floor(b0) * 2.0 + 1.0;
                float4 s1 = floor(b1) * 2.0 + 1.0;
                float4 sh = -step(h, float4(0.0, 0.0, 0.0, 0.0));
                
                float4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
                float4 a1 = b1.xzyw + s1.xzyw * sh.zzww;
                
                float3 p0 = float3(a0.xy, h.x);
                float3 p1 = float3(a0.zw, h.y);
                float3 p2 = float3(a1.xy, h.z);
                float3 p3 = float3(a1.zw, h.w);
                
                // Normalise gradients
                float4 norm = taylorInvSqrt(float4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
                p0 *= norm.x;
                p1 *= norm.y;
                p2 *= norm.z;
                p3 *= norm.w;
                
                // Mix final noise value
                float4 m = max(0.5 - float4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
                m = m * m;
                return 105.0 * dot(m * m, float4(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
            }

            float max(float m, float a, float x)
            {
                return max(m, max(a, x));
            }
            float min(float m, float a, float x)
            {
                return min(m, min(a, x));
            }

            // https://jcgt.org/published/0007/03/04/paper.pdf
            // x is distance to box, y is max distance trough box
            float2 RaycastIntersectBox(float3 boxPosition, float3 boxSize, float3 rayPosition, float3 rayDir)
            {
                float3 bMin = boxPosition - boxSize;
                float3 bMax = boxPosition + boxSize;

                float3 t0 = (bMin - rayPosition) / rayDir;
                float3 t1 = (bMax - rayPosition) / rayDir;

                float3 tMin = min(t0, t1);
                float3 tMax = max(t0, t1);

                float minDistanceToBox = max(0, max(tMin.x, tMin.y, tMin.z));
                float maxDistanceToBox = max(0, min(tMax.x, tMax.y, tMax.z));

                // rayorigin + raydir * minDistanceToBox is the world position of entry point and
                // rayorigin + raydir * maxDistanceToBox is the world position of exit point
                // to get distance between points we can disregard the rayorigin + raydir since its offset is equal for both
                // and prevent the distance from dropping below 0, since nothing behind camera should be calculated.
                float distanceWithinBox = max(0, maxDistanceToBox - minDistanceToBox);
                float distanceToBox = max(0, minDistanceToBox);

                // minDistanceToBox <= maxDistanceToBox means ray intersects with box
                return float2(distanceToBox, distanceWithinBox);
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
                return saturate(((simplexNoise(worldPosition + _Time.yyy * 0.3) + 1.0) * 0.5) - 0.2) * 3.0;
            }

            //                                                                         transmittance ↓      ↓ density
            // transmittance is light reaching camera that dosent get absorbed or inScattering away, T = e^-d.
            // beer's law adapted from https://advances.realtimerendering.com/s2015/The%20Real-time%20Volumetric%20Cloudscapes%20of%20Horizon%20-%20Zero%20Dawn%20-%20ARTR.pdf
            float BeersLambertLaw(float density)
            {
                return exp(-density);
            }

            float BlueNoise(float2 uv, uint totalFrameCount)
            {
                float2 textureResolution = float2(64, 64);
                float2 textureResReciprocal = 1.0 / textureResolution;
                const float goldenRatioCondjugate = 0.6180339887;

                float2 aspectUV = uv * _ScreenParams.xy * textureResReciprocal; // Screen aspect adjusted uv
                float noise = SAMPLE_TEXTURE2D(_Blue, sampler_LinearRepeat, aspectUV).x; // bilinear sample for smoother noise
                return frac(noise + float(totalFrameCount) * goldenRatioCondjugate);
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float depth = SampleSceneDepth(IN.texcoord); // non linear depth
                float3 WorldPos = ComputeWorldSpacePosition(IN.texcoord, depth, UNITY_MATRIX_I_VP); // reconstructs worldposition from depth

                float3 rayOrigin = GetCameraPositionWS();
                float3 rayDir = normalize(WorldPos - rayOrigin);
                /*float rayLength = rayDir.Length;
                rayDir /= rayLength;*/

                float2 intersect = RaycastIntersectBox(boundsPosition, boundsSize, rayOrigin, rayDir);
                float distanceToBox = intersect.x;
                float distanceWithinBox = intersect.y;
                float maxDistanceToBox = distanceToBox + distanceWithinBox;
 
                // Early exit if not intersecting with bounding box
                half4 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, IN.texcoord);
                if (distanceWithinBox == 0) // Ray dosent intersect with bouding box
                    return color;

                
                Light mainLight = GetMainLight();
                float3 lightDir = mainLight.direction; // WS direction from light to surface
                float HG = HenyeyGreenstein(lightDir, rayDir, _Scattering);


                float3 transmittance = 1.0;
                float3 inScattering = 0.0;
                
                uint totalFrameCount = (uint)(_Time.y * 144.0); // 144 should idealy be current FPS
                float debanding = BlueNoise(IN.texcoord, totalFrameCount);

                float distanceTraveled = distanceToBox + debanding * _StepLength;
                float maxRayDist = min(_MaxMarchDistance, maxDistanceToBox);
                
                [loop] while (distanceTraveled < maxRayDist)
                {
                    float3 rayPosition = rayOrigin + rayDir * distanceTraveled;
                    
                    // start marching towards lightsource
                    float lightrayTransmittance = 1.0;
                    
                    float3 lightrayDir = lightDir;
                    float distanceToLightTraveled = debanding * _LightrayStepLength; // increment avoids sampling at known position
                    float distanceWithinBox = RaycastIntersectBox(boundsPosition, boundsSize, rayPosition, lightrayDir).y;
                    float maxLightMarchDistance = min(_StepsTowardsLight * _LightrayStepLength, distanceWithinBox - _LightrayStepLength);
                    
                    
                    [loop] while (distanceToLightTraveled < maxLightMarchDistance)
                    {
                        distanceToLightTraveled += _LightrayStepLength; 

                        float3 lightRayPosition = rayPosition + lightrayDir * distanceToLightTraveled;

                        float density = SampleDensity(lightRayPosition);
                        float beerLambert = BeersLambertLaw(density * _LightrayStepLength);
                        lightrayTransmittance *= beerLambert;

                    }
                    // done matching towards lightsource

                    float density = SampleDensity(rayPosition);
                    float beerLambert = BeersLambertLaw(density * _StepLength);
                    float absoption = 1.0 - beerLambert;
                    
                    float3 sunAmountHere = mainLight.color * lightrayTransmittance;
                    float3 scatter = sunAmountHere * HG * absoption;
                    
                    inScattering += transmittance * scatter;
                    transmittance *= beerLambert;

                    distanceTraveled += _StepLength;
                }

                return float4(color.rgb * transmittance + inScattering, 1.0);
            }
            ENDHLSL
        }
    }
}