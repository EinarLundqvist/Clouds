Shader "Custom/SH_Clouds"
{
    Properties
    {
        // scatting & density
        _Scattering ("Scattering", Range(-1, 1)) = 0.7
        _ScatteringStrength ("Scattering Strength", Range(0.0, 1.0)) = 0.104
        _PowderStregth ("Powder Strength", Range(0.0, 3.0)) = 0.709
        _DensityMultiplier ("Density Multiplier", Range(0.0, 5.0)) = 0.66
        _DensityFalloffFromBounds ("DensityFalloff from bounds", Range(0.01, 1000.0)) = 10
        _DensityFalloffSmoothness ("DensityFalloff Smoothness", Range(0.01, 1000.0)) = 10
        _DensityFarplaneFalloff ("Density farplane Falloff", Range(0.0, 10000.0)) = 0

        // cloud color
        _CloudColor ("Cloud Color", Color) = (0.8207547, 0.8207547, 0.8207547, 1)
        _AmbientBottom ("Ambient Top", Color) = (1, 1, 1, 1)
        _AmbientTop ("Ambient Bottom", Color) = (0.41, 0.4494652, 0.4823529, 1)
        
        // ray marching
        _StepLength ("Min Step Length", Range(10, 100)) = 50
        _MaxStepLength ("Max Step Length", Range(100, 4000)) = 500

        //Light marching
        _LightrayStepLength ("Lightray Length", Range(5.0, 100.0)) = 50.0
        _toLightSearchDistance ("to Light Search Distance", int) = 100
        _Blue ("Blue", 2D) = "white" {}
        
        // march culling
        _FarPlane ("Far Plane", float) = 4000.0
        _TroughBoxMaxDistance ("Trough Box Max Distance", float) = 4000.0
        _VisualizeStepLength ("Visualize StepLength", Range(0.0, 1.0)) = 0.0
        _StepLengthFalloff ("Quality Falloff Exponent", Range(1, 10.0)) = 1.0
        _StepLengthFalloffSafeRadius ("Quality Falloff Safe Radius", Range(0.0, 2000.0)) = 0.0
        
        // Noise settings
        _CloudNoise("Cloud Noise", 3D) = "white" {}
        _ShapeNoiseThreshold ("Noise Threshold", Range(0.0, 1.0)) = 0.438
        _ShapeNoiseScale ("Noise Scale", float) = 3
        
        _CloudNoise2("Detail Noise", 3D) = "white" {}
        _UseDetailNoise ("Use Detail Noise", Range(0.0, 1.0)) = 1
        _DetailNoiseThreshold ("Detail Noise Threshold", Range(0.0, 1.0)) = 0.0
        _DetailNoiseScale ("Detail Noise Scale ", float) = 10
        _DetailErotionStrength ("Detail Erotion Strength", Range(-1.0, 1.0)) = -0.228
        
        _CloudNoise3 ("Large mask noise", 3D) = "white" {}
        _UseLargeMaskNoise ("Use large mask noise", Range(0.0, 1.0)) = 1
        _LargeMaskNoiseThreshold ("Large mask noise threshold", Range(0.0, 1.0)) = 0.2
        _LargeMaskNoiseScale ("Large mask noise scale", float) = 5
        _LargeMaskSharpness ("Large mask sharpness", Range(0.0, 2.0)) = 0.0
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

            TEXTURE3D_FLOAT(_CloudNoise);
            TEXTURE3D_FLOAT(_CloudNoise2);
            TEXTURE3D_FLOAT(_CloudNoise3);
            TEXTURE2D_FLOAT(_Blue);
            SAMPLER(sampler_CloudNoise);
            SAMPLER(sampler_CloudNoise2);
            SAMPLER(sampler_CloudNoise3);
            SAMPLER(sampler_Blue);

            CBUFFER_START(UnityPerMaterial)

                // scattering & density
                float _Scattering;
                float _ScatteringStrength;
                float _PowderStregth;
                float _DensityMultiplier;
                float _DensityFalloffFromBounds;
                float _DensityFalloffSmoothness;
                float _DensityFarplaneFalloff;
                
                // ray maching
                float _StepLength;
                float _MaxStepLength;
                
                // light ray maching
                float _LightrayStepLength;
                float _toLightSearchDistance;

                // maching optimization
                float _FarPlane;
                float _StepLengthFalloff;
                float _TroughBoxMaxDistance;
                float _VisualizeStepLength;
                float _StepLengthFalloffSafeRadius;

                //color
                float3 _CloudColor;
                float3 _AmbientBottom;
                float3 _AmbientTop;

                // shape noise
                float _ShapeNoiseThreshold;
                float _ShapeNoiseScale;

                // detailShapes noise
                float _DetailNoiseThreshold;
                float _DetailNoiseScale;
                float _UseDetailNoise;
                float _DetailErotionStrength;

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
                return ((1.0 - g2) / pow(1.0 + g2 - 2.0 * g * cosTheta, 1.5)) * _ScatteringStrength;
            }

            float BoundsFalloffMask(float3 worldPosition)
            {
                float3 offsetFromCenterOfBounds = worldPosition - boundsPosition;
                float3 maxDistToBounds = boundsSize - abs(offsetFromCenterOfBounds);
                float3 falloffToBounds = smoothstep(-_DensityFalloffSmoothness, _DensityFalloffFromBounds, maxDistToBounds);
                return falloffToBounds.x * falloffToBounds.y * falloffToBounds.z;
            }

            float FarplaneFalloff(float3 worldPosition)
            {
                float distanceToPos = length(worldPosition - GetCameraPositionWS());
                float fadeStart = _FarPlane - _DensityFarplaneFalloff;
                
                return pow(smoothstep(fadeStart, _FarPlane, distanceToPos), 10);
            }

            float SampleDensity(float3 worldPosition)
            {
                float LargeMask = 1.0;
                if (_UseLargeMaskNoise)
                {
                    float3 largeUVW = worldPosition * _LargeMaskNoiseScale * 0.0001;
                    LargeMask = saturate(SAMPLE_TEXTURE3D(_CloudNoise3, sampler_CloudNoise3, largeUVW) + _LargeMaskNoiseThreshold);

                    float erosion = LargeMask * LargeMask * -_LargeMaskSharpness;
                    
                    LargeMask = saturate(LargeMask - erosion);

                    if (LargeMask == 0)
                        return 0.0;
                }


                float boundsFalloff = 1.0 - BoundsFalloffMask(worldPosition);
                float farplaneFalloff = FarplaneFalloff(worldPosition);

                float3 shapeUVW = worldPosition * _ShapeNoiseScale * 0.0001; //+ _Time.yyy * 0.03;
                float cloudShapes = saturate(SAMPLE_TEXTURE3D(_CloudNoise, sampler_CloudNoise, shapeUVW) * LargeMask - boundsFalloff - farplaneFalloff);
                if (cloudShapes == 0)
                    return 0.0;


                float detailShapes = 1.0;
                if (_UseDetailNoise)
                {
                    float3 detailUVW = worldPosition * _DetailNoiseScale * 0.0001 + _Time.yyy * 0.01;
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
                const float goldenRatioCondjugate = 0.6180339887;

                float2 aspectUV = uv * _ScreenParams.xy * textureResReciprocal; // Screen aspect adjusted uv
                float noise = SAMPLE_TEXTURE2D(_Blue, sampler_Blue, aspectUV).x; // bilinear sample for smoother noise
                return frac(noise + float(totalFrameCount) * goldenRatioCondjugate);
            }

            float3 ambientLighting(float3 worldSamplePosition)
            {
                float worldPositionY = worldSamplePosition.y;
                float boundsMiddleY = boundsPosition.y;
                float halfHeight = boundsSize.y;

                float top = boundsMiddleY + halfHeight;
                float bot = boundsMiddleY - halfHeight;

                float invLerp = saturate((worldPositionY - bot) / (top - bot));
                
                return lerp(_AmbientBottom, _AmbientTop, 1 - invLerp);
            }
            // adapted from https://www.mattiasstrand.com/posts/volumetric-fog/
            float AdjustStepLength(float StepLength, float distanceFromCamera)
            {
                float beyondSafeDistance = max(distanceFromCamera - _StepLengthFalloffSafeRadius, 0.0); // distance farther out then safe
                float t = saturate(beyondSafeDistance / _FarPlane); // normalized distance between farplane and 0.0, 0 beeing safe distance
                float warpedT = pow(t, _StepLengthFalloff);
                return lerp(StepLength, _MaxStepLength, warpedT);
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

                float2 intersect = RaycastIntersectBox(boundsPosition, boundsSize, rayOrigin, rayDir);
                float distanceToBox = intersect.x;
                float distanceWithinBox = intersect.y;
                float maxDistanceToBox = distanceToBox + distanceWithinBox;
 
                // Early exit if not intersecting with bounding box
                half4 backgroundColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, IN.texcoord);
                if (distanceToBox > rayLength ||  distanceWithinBox == 0) //isnt infront, or Ray dosent intersect with bouding box
                    return backgroundColor;

                
                Light mainLight = GetMainLight();
                float3 lightDir = mainLight.direction; // WS direction from surface to light
                float HG = HenyeyGreenstein(lightDir, rayDir, _Scattering);

                float3 debugColor = float3(0, 0, 0);

                float3 transmittance = 1.0;
                float3 inScattering = 0.0;
                
                uint totalFrameCount = (uint)(_Time.y * 144.0); // 144 should idealy be current FPS
                float debanding = _VisualizeStepLength ? 0.0 : BlueNoise(IN.texcoord, totalFrameCount);

                float firstStep = AdjustStepLength(_StepLength, distanceToBox);
                float distanceTraveled = distanceToBox + debanding * firstStep;
                float maxRayDist = min(maxDistanceToBox, distanceToBox + _TroughBoxMaxDistance);
                
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
                        float3 rndColor = float3(Hash(seed), Hash(seed + 13.37), Hash(seed + 67.420));
                        debugColor = rndColor * (1 - (distanceTraveled / maxRayDist));

                        if (t < _StepLengthFalloffSafeRadius)
                            debugColor = float4(1.0, 0.0, 0.0, 1.0);

                        return float4(debugColor, 1.0);
                    }
                    // debug coloring end


                    // start marching towards lightsource
                    float lightrayTransmittance = 1.0;
                    
                    float3 lightrayDir = lightDir;
                    float distanceToLightTraveled = frac(debanding * 987.6543) * _LightrayStepLength; // increment avoids sampling at known position
                    float distanceWithinBox = RaycastIntersectBox(boundsPosition, boundsSize, rayPosition, lightrayDir).y;
                    float maxLightMarchDistance = min(_toLightSearchDistance, distanceWithinBox - _LightrayStepLength);
                    
                    [loop] while (distanceToLightTraveled < maxLightMarchDistance)
                    {
                        distanceToLightTraveled += _LightrayStepLength; 
                        
                        float3 lightRayPosition = rayPosition + lightrayDir * distanceToLightTraveled;
                        
                        float density = SampleDensity(lightRayPosition);
                        float beerLambert = BeerLambert(density * _LightrayStepLength);
                        lightrayTransmittance *= beerLambert;
                        
                    }
                    // done matching towards lightsource
                    
                    float beerLambert = BeerLambert(density * adjustedStepLength);
                    float absoption = 1.0 - beerLambert;
                    
                    float powder = lerp(1.0, Powder(density * adjustedStepLength), -_PowderStregth);
                    float3 sunAmountHere = mainLight.color * lightrayTransmittance * powder;
                    float3 ambient = ambientLighting(rayPosition);
                    float3 scatter = (sunAmountHere * HG + ambient) * absoption * _CloudColor;
                    
                    inScattering += transmittance * scatter;
                    transmittance *= beerLambert;
                }

                float3 cloudColor = backgroundColor.rgb * transmittance + inScattering;
                if (_VisualizeStepLength) cloudColor *= debugColor;

                return float4(cloudColor, 1.0);
            }
            ENDHLSL
        }
    }
}