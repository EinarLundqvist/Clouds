using System;
using UnityEditor;
using UnityEngine;

public class S_3DTextureGenerator : MonoBehaviour
{
    [SerializeField] private int resolution = 32;
    [SerializeField] TextureFormat textureFormat = TextureFormat.R8;
    [SerializeField] TextureWrapMode wrapMode = TextureWrapMode.Clamp;
    [SerializeField] FilterMode filterMode = FilterMode.Trilinear;
    [SerializeField] private string savePath = "Assets/Clouds/CloudNoise.asset";
    [SerializeField] private ComputeShader NoiseCompute;

    public void CreateTexture3D()
    {
        
    }
    void  OnValidate()
    {
        int size = resolution;

        // Create the texture and apply the parameters
        Texture3D texture = new Texture3D(size, size, size, textureFormat, false);
        texture.wrapMode = wrapMode;
        texture.filterMode = filterMode;

        // Create a 3-dimensional flat array to store color data
        float[] density = new float[size * size * size];

        ComputeBuffer densityBuffer = new ComputeBuffer(density.Length, sizeof(float));
        Dispatch(densityBuffer, density.Length);
        densityBuffer.GetData(density); // copies the density buffer from the GPU to the density float array

        // Copy the color values to the texture
        texture.SetPixelData(density, 0);

        for (int i = 0; i < 10; i++)
        {
            print("density: " + density[i]);
        }

        // Apply the changes to the texture and upload the updated texture to the GPU
        texture.Apply();

        // Save the texture to your Unity Project
        if (AssetDatabase.AssetPathExists(savePath))
        {
            Texture3D existingTexture = AssetDatabase.LoadAssetAtPath<Texture3D>(savePath);
            EditorUtility.CopySerialized(texture, existingTexture);
            AssetDatabase.SaveAssets();
        }
        else
            AssetDatabase.CreateAsset(texture, savePath);
    }

    private void Dispatch(ComputeBuffer densityBuffer, int bufferLength)
    {
        int kernelIndex = NoiseCompute.FindKernel("FillWithRed");
        NoiseCompute.SetBuffer(kernelIndex, "ResultBuffer", densityBuffer);

        int threadGroups = Mathf.CeilToInt(bufferLength / 64.0f);
        NoiseCompute.Dispatch(kernelIndex, threadGroups, 1, 1);
    }
}