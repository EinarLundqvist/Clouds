using Unity.Mathematics;
using UnityEngine;

[ExecuteAlways]
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
    private Vector4 intersecting;

    void Update()
    {
        currentBounds = new Box(boundingBox.position, boundingBox.localScale);

        intersecting = RaycastIntersectBox(currentBounds, transform.position, transform.forward);

        entryPosition = transform.position + transform.forward * intersecting.x;
        exitPosition = transform.position + transform.forward * intersecting.y;
    }

    void OnDrawGizmos()
    {
        Gizmos.color = Color.blue;
        bool isIntersecting = intersecting.x <= intersecting.y;
        if (isIntersecting)
        {
            Gizmos.DrawLine(entryPosition, entryPosition + transform.forward * Vector3.Distance(entryPosition, exitPosition));
            Gizmos.color = Color.green;
            Gizmos.DrawSphere(entryPosition, 0.2f);
            Gizmos.color = Color.red;
            Gizmos.DrawSphere(exitPosition, 0.2f);
        }

        if (!isIntersecting)
            return;

        float maxMarchDistance = 50;
        float stepLength = 0.5f;
        
        float distanceTraveled = intersecting.z;
        float maxRayDist = Mathf.Min(maxMarchDistance, intersecting.z + (intersecting.z + intersecting.w));
        while (distanceTraveled <= maxRayDist)
        {
            float3 rayPosition = transform.position + transform.forward * distanceTraveled;

            if (distanceTraveled > intersecting.z + intersecting.w)
                break;

            float normalizedDistanceTraveled = distanceTraveled / maxRayDist;
            float brightnessBoost = 0.3f;
            Gizmos.color = new Color(normalizedDistanceTraveled + brightnessBoost, 1 - normalizedDistanceTraveled + brightnessBoost, 1 - normalizedDistanceTraveled + brightnessBoost);
            Gizmos.DrawCube(rayPosition, Vector3.one * (normalizedDistanceTraveled * 0.15f + 0.1f));
            distanceTraveled += stepLength;
            
        }
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
    Vector4 RaycastIntersectBox(Box box, Vector3 rayPosition, Vector3 rayDir)
    {
        Vector3 half = box.size * 0.5f;
        Vector3 bMin = box.position - half;
        Vector3 bMax = box.position + half;

        Vector3 t0 = Vec3Divide(bMin - rayPosition, rayDir);
        Vector3 t1 = Vec3Divide(bMax - rayPosition, rayDir);

        float3 tMin = Vec3Min(t0, t1);
        float3 tMax = Vec3Max(t0, t1);

        float minDistanceToBox = Mathf.Max(0, Mathf.Max(tMin.x, tMin.y, tMin.z));
        float maxDistanceToBox = Mathf.Max(0, Mathf.Min(tMax.x, tMax.y, tMax.z));

        float distanceWithinBox = Mathf.Max(0, maxDistanceToBox - minDistanceToBox);
        float distanceToBox = Mathf.Max(0, minDistanceToBox);

        // minDistanceToBox <= maxDistanceToBox means ray intersects with box
        
        return new Vector4(minDistanceToBox, maxDistanceToBox, distanceToBox, distanceWithinBox);
    }
}
