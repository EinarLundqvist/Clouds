Shader "Custom/SH_Clouds"
{
    Properties
    {
        [Space(10)]
        [Header(Scattering and density)]
        [Space(5)]
        _Scattering ("Scattering", Range(-1, 1)) = 0.7
        _ScatteringStrength ("Scattering Strength", Range(0.0, 5.0)) = 0.175
        _DualLobeRatio ("Dual lobe ratio", Range(0.0, 1.0)) = 1.5

        _PowderStregth ("Powder Strength", Range(0.0, 3.0)) = 3
        _DensityMultiplier ("Density Multiplier", Range(0.0, 5.0)) = 0.8
        _DensityFalloffFromBounds ("DensityFalloff from bounds", Range(0.01, 1000.0)) = 196
        _DensityFalloffSmoothness ("DensityFalloff Smoothness", Range(0.01, 1000.0)) = 328
        _DensityFarplaneFalloff ("Density farplane Falloff", Range(0.0, 100000.0)) = 0

        [Space(10)]
        [Header(Cloud color)]
        [Space(5)]
        _CloudColor ("Cloud Color", Color) = (0.8207547, 0.8207547, 0.8207547, 1)
        _AmbientBottom ("Ambient Top", Color) = (1, 1, 1, 1)
        _AmbientTop ("Ambient Bottom", Color) = (0.4379464, 0.4768749, 0.545, 1)
        
        [Space(10)]
        [Header(Ray marching)]
        [Space(5)]
        _StepLength ("Min Step Length", Range(10, 100)) = 10.0
        _MaxStepLength ("Max Step Length", Range(100, 4000)) = 200.0
        _StepLengthFalloff ("Quality Falloff Exponent", Range(1.0, 10.0)) = 2.0
        _StepLengthFalloffSafeRadius ("Quality Falloff Safe Radius", Range(0.0, 2000.0)) = 500.0
        
        [Space(10)]
        [Header(Light marching)]
        [Space(5)]
        _maxLightmarchDistance ("max Lightmarch Distance", Range(0.0, 200.0)) = 75.0
        [Space(5)]
        _sampelEveryNSteps ("sample every n steps (skip samples)", Range(0, 4)) = 2
        [Space(8)]
        _LightrayStepLength ("Lightray Length", Range(5.0, 50.0)) = 5.0
        _MaxLightrayStepLength ("Max Lightray Length", Range(20.0, 200.0)) = 100.0
        [Space(8)]
        _LightrayStepLengthFalloff ("Lightmarch Falloff Exponent", Range(1.0, 10.0)) = 1.0
        _LightrayStepFalloffSafeRadius ("Lightray Step Falloff Safe Radius", Range(0.0, 2000.0)) = 500.0
        [Space(8)]
        _Blue ("Blue", 2D) = "white" {}
        
        [Space(10)]
        [Header(Optimization)]
        [Space(5)]
        _FarPlane ("Far Plane", float) = 30000.0
        _TroughBoxMaxDistance ("Trough Box Max Distance", float) = 20000.0
        [Toggle] _VisualizeStepLength ("Visualize StepLength", Range(0.0, 1.0)) = 0.0
        _DensityThreshold ("raymarch max density acculmulation threshold", Range(0.0, 0.1)) = 0.01
        _LightmarchDensityThreshold ("Lightmarch max density acculmulation threshold", Range(0.0, 0.1)) = 0.03
        
        [Space(20)]
        [Header(Noise)]
        [Space(5)]
        _CurlNoise ("Curl Noise", 2D) = "white" {}
        _CurlStrength ("Curl Strength", Range(0.0, 2020.0)) = 0.5
        _CurlScale ("Curl scale", float) = 15
        [Space(20)]
        
        [Space(5)]
        _CloudNoise("Cloud Noise", 3D) = "white" {}
        _ShapeNoiseThreshold ("Noise Threshold", Range(0.0, 1.0)) = 0.438
        _ShapeNoiseScale ("Noise Scale", float) = 3
        
        [Space(20)]
        _CloudNoise2("Detail Noise", 3D) = "white" {}
        [Toggle] _UseDetailNoise ("Use Detail Noise", Range(0.0, 1.0)) = 1
        _DetailNoiseThreshold ("Detail Noise Threshold", Range(0.0, 1.0)) = 0.0
        _DetailNoiseScale ("Detail Noise Scale ", float) = 15
        _DetailErotionStrength ("Detail Erotion Strength", Range(-1.0, 1.0)) = -0.306
        _DetailNoiseRenderDistance ("Detail Noise render distance", Range(0.0, 50000)) = 14238.0
        
        [Space(20)]
        _CloudNoise3 ("Large mask noise", 3D) = "white" {}
        [Toggle] _UseLargeMaskNoise ("Use large mask noise", Range(0.0, 1.0)) = 1
        _LargeMaskNoiseThreshold ("Large mask noise threshold", Range(0.0, 1.0)) = 0.121
        _LargeMaskNoiseScale ("Large mask noise scale", float) = 0.94
        _LargeMaskSharpness ("Large mask sharpness", Range(0.0, 2.0)) = 1.28
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
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            float3 _BoundsPosition;
            float3 _BoundsSize;
            float4 _CloudRTSize;

            TEXTURE3D_FLOAT(_CloudNoise);
            TEXTURE3D_FLOAT(_CloudNoise2);
            TEXTURE3D_FLOAT(_CloudNoise3);
            TEXTURE2D_FLOAT(_Blue);
            TEXTURE2D(_CurlNoise);
            SAMPLER(sampler_CloudNoise);
            SAMPLER(sampler_CloudNoise2);
            SAMPLER(sampler_CloudNoise3);
            SAMPLER(sampler_Blue);
            SAMPLER(sampler_CurlNoise);

            CBUFFER_START(UnityPerMaterial)

                // scattering & density
                float _Scattering;
                float _ScatteringStrength;
                float _DualLobeRatio;
                float _PowderStregth;
                float _DensityMultiplier;
                float _DensityFalloffFromBounds;
                float _DensityFalloffSmoothness;
                float _DensityFarplaneFalloff;
                
                // ray maching
                float _StepLength;
                float _MaxStepLength;
                
                // light ray maching
                float _maxLightmarchDistance;
                int _sampelEveryNSteps;
                float _LightrayStepLength;
                float _MaxLightrayStepLength;
                float _LightrayStepLengthFalloff;
                float _LightrayStepFalloffSafeRadius;

                // optimization
                float _FarPlane;
                float _StepLengthFalloff;
                float _TroughBoxMaxDistance;
                float _VisualizeStepLength;
                float _StepLengthFalloffSafeRadius;
                float _DensityThreshold;
                float _LightmarchDensityThreshold;

                //color
                float3 _CloudColor;
                float3 _AmbientBottom;
                float3 _AmbientTop;

                // curl noise 
                float _CurlStrength;
                float _CurlScale;

                // shape noise
                float _ShapeNoiseThreshold;
                float _ShapeNoiseScale;

                // detailShapes noise
                float _DetailNoiseThreshold;
                float _DetailNoiseScale;
                float _UseDetailNoise;
                float _DetailErotionStrength;
                float _DetailNoiseRenderDistance;

                // large mask nosie 
                int _UseLargeMaskNoise;
                float _LargeMaskNoiseThreshold;
                float _LargeMaskNoiseScale;
                float _LargeMaskSharpness;

            CBUFFER_END

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

                float distanceToBox = max(0, max(tMin.x, tMin.y, tMin.z));
                float maxDistanceToBox = max(0, min(tMax.x, tMax.y, tMax.z));

                // rayorigin + raydir * minDistanceToBox is the world position of entry point and
                // rayorigin + raydir * maxDistanceToBox is the world position of exit point
                // to get distance between points we can disregard the rayorigin + raydir since its offset is equal for both
                // and prevent the distance from dropping below 0, since nothing behind camera should be calculated.
                float distanceWithinBox = max(0, maxDistanceToBox - distanceToBox);

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

            float dualLobeHenyeyGreenstein(float3 lightDir, float3 viewDir, float g)
            {
                float HG = HenyeyGreenstein(lightDir, viewDir, g);
                float backHG = HenyeyGreenstein(lightDir, viewDir, -g * 0.5); // half the backwards scattering for softer halo
                return lerp(HG, backHG, _DualLobeRatio) * _ScatteringStrength;
            }

            float BoundsFalloffMask(float3 worldPosition)
            {
                float3 offsetFromCenterOfBounds = worldPosition - _BoundsPosition;
                float3 maxDistToBounds = _BoundsSize - abs(offsetFromCenterOfBounds);
                float3 falloffToBounds = smoothstep(-_DensityFalloffSmoothness, _DensityFalloffFromBounds, maxDistToBounds);
                return falloffToBounds.x * falloffToBounds.y * falloffToBounds.z;
            }

            float FarplaneFalloff(float3 worldPosition, float3 cameraPos)
            {
                float distanceToPos = length(worldPosition - cameraPos);
                float fadeStart = _FarPlane - _DensityFarplaneFalloff;
                
                return pow(smoothstep(fadeStart, _FarPlane, distanceToPos), 2);
            }

            bool isDistanceFromCamera(float checkDistance, float3 worldPosition, float3 cameraPosition)
            {
                return checkDistance > length(worldPosition - cameraPosition);
            }

            float3 Curl(float3 UVW)
            {
                float2 uv  = UVW.xy - _Time.yy * 0.01;
                float2 curl = (SAMPLE_TEXTURE2D(_CurlNoise, sampler_CurlNoise, uv * _CurlScale * 0.0001).rg - 1.0) * 0.5;
                return UVW + float3(curl.x, 0, -curl.y) * _CurlStrength;
            }

            float SampleDensity(float3 UVW, bool UseCurl = true)
            {
                float3 cameraPosition = GetCameraPositionWS();
                float boundsFalloff = 1.0 - BoundsFalloffMask(UVW);
                float farplaneFalloff = FarplaneFalloff(UVW, cameraPosition);
                
                if (boundsFalloff + farplaneFalloff >= 1.0)
                    return 0.0;

                float LargeMask = 1.0;
                if (_UseLargeMaskNoise) 
                {
                    float3 largeUVW = UVW * _LargeMaskNoiseScale * 0.0001;
                    LargeMask = saturate(SAMPLE_TEXTURE3D(_CloudNoise3, sampler_CloudNoise3, largeUVW) + _LargeMaskNoiseThreshold);

                    float erosion = LargeMask * LargeMask * -_LargeMaskSharpness;
                    
                    LargeMask = saturate(LargeMask - erosion);

                    if (LargeMask == 0)
                        return 0.0;
                }



                float3 shapeUVW = UVW * _ShapeNoiseScale * 0.0001; //+ _Time.yyy * 0.03;
                float cloudShapes = saturate(SAMPLE_TEXTURE3D(_CloudNoise, sampler_CloudNoise, shapeUVW) * LargeMask - boundsFalloff - farplaneFalloff);
                if (cloudShapes == 0)
                    return 0.0;

                float detailShapes = 1.0;
                if (_UseDetailNoise && isDistanceFromCamera(_DetailNoiseRenderDistance, UVW, cameraPosition))
                {
                    if (UseCurl)
                        UVW = Curl(UVW);

                    float3 detailUVW = UVW * _DetailNoiseScale * 0.0001 + _Time.yyy * 0.01;
                    detailShapes = saturate(SAMPLE_TEXTURE3D(_CloudNoise2, sampler_CloudNoise2, detailUVW) - _DetailNoiseThreshold);
                }

                float edge = 1.0 - cloudShapes;
                float erosion = detailShapes * edge * edge * _DetailErotionStrength;
                
                return saturate(cloudShapes - _ShapeNoiseThreshold - erosion) * _DensityMultiplier;
            }
            float Hash(float p)
            {
                return frac(sin(dot(p, 12.9898f)) * 43758.5453f);
            }

            //                                                                         transmittance ↓      ↓ density
            // transmittance is light reaching camera that dosent get absorbed or inScattering away, T = e^-d.
            // beer's law adapted from https://advances.realtimerendering.com/s2015/The%20Real-time%20Volumetric%20Cloudscapes%20of%20Horizon%20-%20Zero%20Dawn%20-%20ARTR.pdf
            float BeerLambert(float density)
            {
                return exp(-density);
            }
            float Powder(float density) 
            {
                return 1.0 - exp(-density * 2.0);
            }

            float BlueNoise(float2 uv, uint totalFrameCount)
            {
                float2 textureResolution = float2(64, 64);
                float2 textureResReciprocal = 1.0 / textureResolution;
                const float goldenRatioCondjugate = 0.6180339887; // using a low discrepancy sequence for better jittering https://en.wikipedia.org/wiki/Low-discrepancy_sequence

                float2 aspectUV = uv * _CloudRTSize.xy * textureResReciprocal; // Screen aspect adjusted uv
                float noise = SAMPLE_TEXTURE2D(_Blue, sampler_Blue, aspectUV).x; // bilinear sample for smoother noise
                return frac(noise + float(totalFrameCount) * goldenRatioCondjugate);
            }

            float3 ambientLighting(float3 worldPosition)
            {
                float worldPositionY = worldPosition.y;
                float boundsMiddleY = _BoundsPosition.y;
                float halfHeight = _BoundsSize.y;

                float top = boundsMiddleY + halfHeight;
                float bot = boundsMiddleY - halfHeight;

                float invLerp = saturate((worldPositionY - bot) / (top - bot));
                
                return lerp(_AmbientBottom, _AmbientTop, 1 - invLerp);
            }
            // adapted from https://www.mattiasstrand.com/posts/volumetric-fog/
            float AdjustStepLength(float originalStepLength, float distanceFromCamera)
            {
                float beyondSafeDistance = max(distanceFromCamera - _StepLengthFalloffSafeRadius, 0.0); // distance farther out then safe
                float t = saturate(beyondSafeDistance / _FarPlane); // normalized distance between farplane and 0.0, 0 beeing safe distance
                float warpedT = pow(t, _StepLengthFalloff);
                return lerp(originalStepLength, _MaxStepLength, warpedT);
            }
            
            float AdjustLightStepLength(float originalStepLength, float normalizedDistanceFromCamera)
            {
                float beyondSafeDistance = max(normalizedDistanceFromCamera * _FarPlane - _LightrayStepFalloffSafeRadius, 0.0); // distance farther out then safe
                float t = saturate(beyondSafeDistance / _FarPlane); // normalized distance between farplane and 0.0, 0 beeing safe distance
                float warpedT = pow(t, _LightrayStepLengthFalloff);
                return lerp(originalStepLength, _MaxLightrayStepLength, warpedT);
            }

            float TowardsLightRaymarch(float3 lightDir, float debanding, float3 rayPosition, float cameraDistance)
            {
                // start marching towards lightsource
                float lightrayTransmittance = 1.0;
                float3 lightrayOrigin = rayPosition;
                
                float adjustedStepLength = AdjustLightStepLength(_LightrayStepLength, cameraDistance / _FarPlane);
                
                float distanceToLightTraveled = debanding * adjustedStepLength; // increment avoids sampling at known position
                float distanceWithinBox = RaycastIntersectBox(_BoundsPosition, _BoundsSize, lightrayOrigin, lightDir).y;
                float maxLightMarchDistance = min(_maxLightmarchDistance, distanceWithinBox - adjustedStepLength);
                
                [loop] while (distanceToLightTraveled < maxLightMarchDistance)
                {
                    distanceToLightTraveled += adjustedStepLength;
                    
                    float3 lightRayPosition = lightrayOrigin + lightDir * distanceToLightTraveled;
                    
                    float density = SampleDensity(lightRayPosition, false);
                    float beerLambert = BeerLambert(density * adjustedStepLength);
                    lightrayTransmittance *= beerLambert;
                    
                    if (lightrayTransmittance <= _LightmarchDensityThreshold)
                        break; 
                    
                }
                // done matching towards lightsource
                return lightrayTransmittance;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float depth = SampleSceneDepth(IN.texcoord); // non linear depth
                float3 WorldPos = ComputeWorldSpacePosition(IN.texcoord, depth, UNITY_MATRIX_I_VP); // reconstructs worldposition from depth

                float3 rayOrigin = GetCameraPositionWS();
                float3 rayDir = WorldPos - rayOrigin;
                float rayLength = length(rayDir);
                rayDir /= rayLength;

                rayLength = min(rayLength, _FarPlane); // limit everything to a far plane
 
                float2 intersect = RaycastIntersectBox(_BoundsPosition, _BoundsSize, rayOrigin, rayDir);
                float distanceToBox = intersect.x;
                float distanceWithinBox = intersect.y;
                float maxDistanceToBox = distanceToBox + distanceWithinBox;
 
                // Early exit if not intersecting with bounding box
                if (distanceToBox > rayLength ||  distanceWithinBox == 0) //isnt infront, or Ray dosent intersect with bouding box
                    return half4(0.0, 0.0, 0.0, 1.0);

                
                Light mainLight = GetMainLight();
                float3 lightDir = mainLight.direction; // WS direction from surface to light
                float HG = dualLobeHenyeyGreenstein(lightDir, rayDir, _Scattering);

                float3 debugColor = float3(0, 0, 0);

                float transmittance = 1.0;
                float3 inScattering = 0.0;
                
                uint totalFrameCount = (uint)(_Time.y * 144.0); // 144 should idealy be current FPS
                float debanding = _VisualizeStepLength ? 0.0 : BlueNoise(IN.texcoord, totalFrameCount);

                float firstStep = AdjustStepLength(_StepLength, distanceToBox);
                float distanceTraveled = distanceToBox + debanding * firstStep;
                float maxRayDist = min(maxDistanceToBox, min(distanceToBox + _TroughBoxMaxDistance, rayLength));

                int lightStepIndex = 0;
                float lastLightmarchTransmittance = 0.0;
                int sampleEvery = max(1, _sampelEveryNSteps);
                
                [loop] while (distanceTraveled < maxRayDist)
                {
                    float3 rayPosition = rayOrigin + rayDir * distanceTraveled;
                    
                    float adjustedStepLength = AdjustStepLength(_StepLength, distanceTraveled);
                    distanceTraveled += adjustedStepLength;

                    float density = SampleDensity(rayPosition);
                    if (density <= 0.0)
                        continue;
                    
                    // debug coloring
                    if (_VisualizeStepLength)
                    {
                        float t = distanceToBox;
                        
                        uint idx = 0; 
                        [loop] while (t < distanceTraveled && idx < 4128) // cap for safety
                        {
                            t += AdjustStepLength(_StepLength, t);
                            idx++;
                        }

                        float seed = (float)idx;
                        float noise = Hash(seed);
                        float3 rndColor = float3(noise, frac(noise + 13.37), frac(noise + 67.420));
                        debugColor = rndColor * (1.0 - (distanceTraveled / maxRayDist));

                        if (t < _StepLengthFalloffSafeRadius)
                            debugColor = float4(1.0, 0.0, 0.0, 0.0);

                        return float4(debugColor, 1.0);
                    }
                    // debug coloring end
                    
                    
                    float beerLambert = BeerLambert(density * adjustedStepLength);
                    float absorption = 1.0 - beerLambert; // absorption is oposite of transmittance
                    if (absorption < 0.002)
                    {
                        transmittance *= beerLambert;
                        continue; // opt out early since absorption removes ≈all in scattering when close to zero
                    }

                    if (lightStepIndex % sampleEvery == 0)
                        lastLightmarchTransmittance = TowardsLightRaymarch(lightDir, frac(debanding * 69.67420), rayPosition, distanceTraveled); // reshash debanding 
                    lightStepIndex++; // increment when lightraymaching could have been preformed
                    
                    float powder = lerp(1.0, Powder(density * adjustedStepLength), -_PowderStregth);
                    float3 sunAmountHere = mainLight.color * lastLightmarchTransmittance * powder;
                    float3 ambient = ambientLighting(rayPosition);
                    float3 scatter = (sunAmountHere * HG + ambient) * absorption * _CloudColor;
                    
                    inScattering += scatter * transmittance;
                    transmittance *= beerLambert;

                    if (transmittance <= _DensityThreshold)
                        break;
                }

                float3 cloudColor = _VisualizeStepLength ? debugColor : inScattering;
                float alpha = transmittance;
                if (_VisualizeStepLength)
                {
                    alpha = 1 - (cloudColor.r + cloudColor.g + cloudColor.b) * (1 / 3);
                    cloudColor = (cloudColor.r + cloudColor.g + cloudColor.b) * (1 / 3);
                }
                

                return float4(cloudColor, alpha);
            }
            ENDHLSL
        }
        Pass
        {
            ZTest Always 
            ZWrite Off 
            Cull Off
            Blend One SrcAlpha
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            half4 frag(Varyings IN) : SV_Target
            {
                return SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, IN.texcoord);
            }
            ENDHLSL
        }
    }
}