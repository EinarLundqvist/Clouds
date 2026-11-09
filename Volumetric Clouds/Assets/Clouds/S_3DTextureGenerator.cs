using UnityEditor;
using UnityEngine;
using UnityEngine.UI;

public class S_3DTextureGenerator : MonoBehaviour
{
    [SerializeField] private bool autoGenerate = false;
    [Space]
    [SerializeField] private int resolution = 32;
    [SerializeField] TextureFormat textureFormat = TextureFormat.RFloat;
    [SerializeField] TextureWrapMode wrapMode = TextureWrapMode.Repeat;
    [SerializeField] FilterMode filterMode = FilterMode.Bilinear;
    [SerializeField] private string savePath = "Assets/Clouds/";
    [SerializeField] private string assetName = "MyCloudNoise";
    [SerializeField] private ComputeShader NoiseCompute;
    [HideInInspector] public Texture3D CloudTexture;

    [Header("Noise Settings")]
    [SerializeField] private int cellAmount = 10;
    [SerializeField, Range(0.0f, 1.0f)] private float seed = 0;

    private void OnValidate()
    {
        if (autoGenerate)
            CreateTexture3D();
    }
    public void CreateTexture3D()
    {
        int size = resolution;

        // Create the texture and apply the parameters
        Texture3D texture = new Texture3D(size, size, size, textureFormat, false);
        texture.wrapMode = wrapMode;
        texture.filterMode = filterMode;
        texture.name = "CloudNoise";

        // Create a 3-dimensional flat array to store color data
        float[] density = new float[size * size * size];
        
        ComputeBuffer densityBuffer = new ComputeBuffer(density.Length, sizeof(float));
        Dispatch(densityBuffer, density.Length);

        densityBuffer.GetData(density); // copies the density buffer from the GPU to the density float array

        densityBuffer.Release(); // release the allocated buffer after its done

        // copy the density values to the 3D texture
        texture.SetPixelData(density, 0);

        // Apply the changes to the texture and upload the updated texture to the GPU
        texture.Apply();

        string assetSavePath = savePath.EndsWith('/') ? savePath + assetName + ".asset" : savePath + '/' + assetName + ".asset";

        // Save the texture to your Unity Project
        if (AssetDatabase.AssetPathExists(assetSavePath))
        {
            Texture3D existingTexture = AssetDatabase.LoadAssetAtPath<Texture3D>(assetSavePath);
            EditorUtility.CopySerialized(texture, existingTexture);
            AssetDatabase.SaveAssets();
        }
        else
            AssetDatabase.CreateAsset(texture, assetSavePath);

        CloudTexture = texture;
    }

    private void Dispatch(ComputeBuffer densityBuffer, int bufferLength)
    {
        int kernelIndex = NoiseCompute.FindKernel("FillWithRed");

        // settings variables
        NoiseCompute.SetBuffer(kernelIndex, "_ResultBuffer", densityBuffer);
        NoiseCompute.SetInt("_Resolution", resolution);
        NoiseCompute.SetInt("_CellAmount", cellAmount);
        NoiseCompute.SetFloat("_Seed", seed);

        int threadGroups = Mathf.CeilToInt(resolution / 8.0f);
        NoiseCompute.Dispatch(kernelIndex, threadGroups, threadGroups, threadGroups);
    }
}