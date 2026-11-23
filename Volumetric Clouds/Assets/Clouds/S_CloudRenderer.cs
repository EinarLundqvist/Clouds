using UnityEngine;
using UnityEngine.InputSystem;

[ExecuteAlways]
public class S_CloudRenderer : MonoBehaviour
{
    public Material fullscreenPass;
    [SerializeField] private Transform boundsBox;
    [SerializeField] private Vector3 boundsSize = Vector3.zero;
    [SerializeField] private Vector3 boundsPosition = Vector3.zero;
    [SerializeField] private GameObject cirroCumulus;
    [SerializeField] private GameObject AltoStratus;
    [HideInInspector] public bool shouldRender = true;

    void Update()
    {
        shouldRender = !Keyboard.current.spaceKey.isPressed;

        cirroCumulus?.SetActive(shouldRender);
        AltoStratus?.SetActive(shouldRender);

        boundsSize = boundsBox.localScale;
        boundsPosition = boundsBox.position;

        fullscreenPass.SetVector("_BoundsPosition", boundsPosition);
        fullscreenPass.SetVector("_BoundsSize", boundsSize * 0.5f);
    }
}