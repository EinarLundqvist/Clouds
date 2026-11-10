using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;
public class S_CloudRenderPass : ScriptableRendererFeature
{
    public Material material;
    [Range(1, 4)] public int downSampleFactor;
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

            TextureHandle cloudTex = renderGraph.CreateTexture(cloudsRTdescription);

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
        pass.mat = material;
        pass.resolutionDownsampleFactor = Mathf.Max(downSampleFactor, 1);
        renderer.EnqueuePass(pass);
    }
}
