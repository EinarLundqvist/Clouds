using UnityEditor;
using UnityEngine;
using UnityEditor.UIElements;
using UnityEngine.UIElements;

[CustomEditor(typeof(S_3DTextureGenerator))]
[CanEditMultipleObjects]
public class S_CloudNoiseGeneratorEditor : Editor
{
    private Image previewImage;
    private PropertyField CreateProperty(string name) { return new PropertyField(serializedObject.FindProperty(name)); }
    
    public override VisualElement CreateInspectorGUI()
    {
        var root = new VisualElement();

        root.Add(CreateProperty("resolution"));
        root.Add(CreateProperty("textureFormat"));
        root.Add(CreateProperty("wrapMode"));
        root.Add(CreateProperty("filterMode"));
        root.Add(CreateProperty("savePath"));
        root.Add(CreateProperty("NoiseCompute"));
        root.Add(CreateProperty("cellAmount"));
        root.Add(CreateProperty("seed"));

        previewImage = new Image
        {
            scaleMode = ScaleMode.ScaleToFit
        };

        previewImage.style.height = 512;
        previewImage.style.marginTop = 6;


        var button = new Button(() => ((S_3DTextureGenerator)target).CreateTexture3D()) { text = "Generate" };
        root.Add(button);

        root.Add(previewImage);

        // Updates initially when inspector is drawn
        UpdateNoisePreview();

        // Updates whenever any inspector property on this target updates
        root.TrackSerializedObjectValue(serializedObject, _ => UpdateNoisePreview());

        return root;
    }

    private void UpdateNoisePreview()
    {
        Texture3D cloudNoise = ((S_3DTextureGenerator)target).CloudTexture;
        if (cloudNoise != null)
        {
            if (previewImage.image != null) DestroyImmediate(previewImage.image);
            previewImage.image = SlideFrom3D(cloudNoise);
        }
    }

    // https://docs.unity.com/en-us/engine/6000.6/script-reference/unityengine/texture2d
    private Texture2D SlideFrom3D(Texture3D cloudNoise)
    {
        Texture2D slice = new Texture2D(cloudNoise.width, cloudNoise.height, TextureFormat.RGBAHalf, false);

        for (int y = 0; y < slice.height; y++)
        for (int x = 0; x < slice.width; x++)
        {
            float sliceData = cloudNoise.GetPixel(x, y, 0).r;
            slice.SetPixel(x, y, new Color(sliceData, sliceData, sliceData, 1.0f));
        }
        slice.Apply();
        return slice;
    }
}