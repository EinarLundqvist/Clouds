using Unity.Mathematics;
using UnityEngine;

public class BoxIntersection : MonoBehaviour
{
    [System.Serializable]
    public struct Box
    {
        public Vector3 position;
        public Vector3 size;

        public Box(Vector3 pos, Vector3 scale)
        {
            position = pos;
            size = scale;
        }
    }
    [SerializeField] private Transform boundingBox;
    [SerializeField] private Box currentBounds;
    
    private Vector3 entryPosition = Vector3.zero;
    private Vector3 exitPosition = Vector3.zero;
    private Vector2 intersecting;

    void Update()
    {

        currentBounds = new Box(boundingBox.position, boundingBox.localScale);

        intersecting = RaycastIntersectBox(currentBounds, transform.position, transform.up);

        entryPosition = transform.position + transform.up * intersecting.x;
        exitPosition = transform.position + transform.up * intersecting.y;
    }

    void OnDrawGizmos()
    {
        Gizmos.color = Color.blue;
        Gizmos.DrawLine(transform.position, transform.position + transform.up * Vector3.Distance(transform.position, exitPosition));
        Gizmos.DrawSphere(transform.position, 0.05f);
        Gizmos.color = Color.green;
        Gizmos.DrawSphere(entryPosition, 0.1f);
        Gizmos.color = Color.red;
        Gizmos.DrawSphere(exitPosition, 0.1f);
    }

    Vector3 Vec3Divide(Vector3 numerator, Vector3 denoninator)
    {
        float x = numerator.x / denoninator.x;
        float y = numerator.y / denoninator.y;
        float z = numerator.z / denoninator.z;

        return new Vector3(x, y, z);
    }
    Vector3 Vec3Min(Vector3 u, Vector3 v)
    {
        float x = Mathf.Min(u.x, v.x);
        float y = Mathf.Min(u.y, v.y);
        float z = Mathf.Min(u.z, v.z);
        return new Vector3(x, y ,z);
    }
    Vector3 Vec3Max(Vector3 u, Vector3 v)
    {
        float x = Mathf.Max(u.x, v.x);
        float y = Mathf.Max(u.y, v.y);
        float z = Mathf.Max(u.z, v.z);
        return new Vector3(x, y, z);
    }

    // https://jcgt.org/published/0007/03/04/paper.pdf
    // x is distance to box, y is max distance trough box
    Vector2 RaycastIntersectBox(Box box, Vector3 rayPosition, Vector3 rayDir)
    {
        Vector3 half = box.size * 0.5f;
        Vector3 bMin = box.position - half;
        Vector3 bMax = box.position + half;

        Vector3 t0 = Vec3Divide(bMin - rayPosition, rayDir);
        Vector3 t1 = Vec3Divide(bMax - rayPosition, rayDir);

        float3 tMin = Vec3Min(t0, t1);
        float3 tMax = Vec3Max(t0, t1);

        float minDistanceToBox = Mathf.Max(tMin.x, tMin.y, tMin.z);
        float maxDistanceToBox = Mathf.Min(tMax.x, tMax.y, tMax.z);

        // minDistanceToBox <= maxDistanceToBox means ray intersects with box
        
        return new Vector2(minDistanceToBox, maxDistanceToBox);
    }
}
