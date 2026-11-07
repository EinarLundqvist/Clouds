using UnityEditor;
using UnityEditor.UIElements;
using UnityEngine.UIElements;

[CustomEditor(typeof(S_3DTextureGenerator))]
[CanEditMultipleObjects]
public class S_CloudNoiseGeneratorEditor : Editor
{
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

        var button = new Button(() => ((S_3DTextureGenerator)target).CreateTexture3D()) { text = "Generate" };
        root.Add(button);

        return root;
    }
}