using UnityEngine;

[ExecuteAlways]
public class S_CloudRenderer : MonoBehaviour
{
    public Material fullscreenPass;
    [SerializeField] private Transform boundsBox;
    [SerializeField] private Vector3 boundsSize = Vector3.zero;
    [SerializeField] private Vector3 boundsPosition = Vector3.zero;

    void Update()
    {
        boundsSize = boundsBox.localScale;
        boundsPosition = boundsBox.position;

        fullscreenPass.SetVector("_BoundsPosition", boundsPosition);
        fullscreenPass.SetVector("_BoundsSize", boundsSize * 0.5f);
    }
}