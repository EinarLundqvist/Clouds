using UnityEngine;
using UnityEngine.UI;
public class S_POIManager : MonoBehaviour
{
    [SerializeField] private Button next, previous;
    [SerializeField] private Camera[] POICameras;
    private int ActiveCameraIndex = 0;

    private void SwitchToCamera(int newIndex)
    {
        ActiveCameraIndex = newIndex;
        foreach (Camera cam in POICameras)
            cam.enabled = false;

        POICameras[newIndex].enabled = true;
    }

    public void NextCamera()
    {
        SwitchToCamera(ActiveCameraIndex + 1);
        previous.interactable = true;

        if (ActiveCameraIndex + 1 == POICameras.Length)
            next.interactable = false;
    }
    public void PreviousCamera()
    {
        SwitchToCamera(ActiveCameraIndex - 1);
        next.interactable = true;

        if (ActiveCameraIndex - 1 < 0)
            previous.interactable = false;
    }
}
