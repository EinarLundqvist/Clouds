using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;
using UnityEngine.Experimental.Rendering;
using System.Runtime.InteropServices.WindowsRuntime;
public class S_CloudRenderFeature : ScriptableRendererFeature
{
    [HideInInspector] public Material material;
    [Range(1, 4)] public int downSampleFactor;
    [HideInInspector] private S_CloudRenderer cloudRenderer;
    class CompositePassData
    {
        public Material mat;
        public TextureHandle clouds;
    }
    class HalfResolutionPass : ScriptableRenderPass
    {
        public Material mat;
        public int resolutionDownsampleFactor = 1;
        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            TextureHandle screenColorTex = frameData.Get<UniversalResourceData>().activeColorTexture;

            TextureDesc cloudsRTdescription = renderGraph.GetTextureDesc(screenColorTex);
            cloudsRTdescription.name = "HalfRes";
            cloudsRTdescription.width /= resolutionDownsampleFactor;
            cloudsRTdescription.height /= resolutionDownsampleFactor;
            cloudsRTdescription.msaaSamples = MSAASamples.None;
            cloudsRTdescription.depthBufferBits = DepthBits.None;
            cloudsRTdescription.colorFormat = GraphicsFormat.R16G16B16A16_SFloat;

            TextureHandle cloudTex = renderGraph.CreateTexture(cloudsRTdescription);
            
            mat.SetVector("_CloudRTSize", new Vector4(cloudsRTdescription.width, cloudsRTdescription.height, 1.0f / cloudsRTdescription.width, 1.0f / cloudsRTdescription.height)); // send new resolution to shader 

            renderGraph.AddBlitPass(new RenderGraphUtils.BlitMaterialParameters(screenColorTex, cloudTex, mat, 0), "Effect");

            using (var builder = renderGraph.AddRasterRenderPass("Cloud Composite", out CompositePassData data))
            {
                data.mat = mat;
                data.clouds = cloudTex;

                builder.UseTexture(cloudTex);
                builder.SetRenderAttachment(screenColorTex, 0, AccessFlags.ReadWrite);

                builder.SetRenderFunc(static (CompositePassData d, RasterGraphContext ctx) =>
                {
                   Blitter.BlitTexture(ctx.cmd, d.clouds, new Vector4(1, 1, 0, 0), d.mat, 1); 
                });
            }
        }
    }
    HalfResolutionPass pass;
    public override void Create()
    {
        pass = new HalfResolutionPass { renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing };
    }
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData data)
    {
        if (cloudRenderer == null)
            cloudRenderer = FindFirstObjectByType<S_CloudRenderer>();

        if (cloudRenderer == null)
        {
            Debug.LogError("No shader found, Assign cloudFullscreenMaterial in CloudRenderer");
            return;
        }
        
        pass.mat = cloudRenderer.fullscreenPass;

        pass.resolutionDownsampleFactor = Mathf.Max(downSampleFactor, 1);
        renderer.EnqueuePass(pass);
    }
}
