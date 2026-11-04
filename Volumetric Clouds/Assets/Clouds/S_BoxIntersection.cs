using System;
using Unity.Mathematics;
using Unity.VisualScripting;
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
    private bool intersecting;

    void Start()
    {
        
    }

    void Update()
    {
        entryPosition = boundingBox.position;
        exitPosition = boundingBox.position + boundingBox.localScale / 2.0f;

        currentBounds = new Box(boundingBox.position, boundingBox.localScale);

        intersecting = RaycastIntersectBox(currentBounds, transform.position, transform.up);
    }

    void OnDrawGizmos()
    {
        Gizmos.color = intersecting ? Color.green : Color.red;
        Gizmos.DrawLine(transform.position, transform.position + transform.up * 3.0f);
        Gizmos.DrawSphere(entryPosition, 0.1f);
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
    bool RaycastIntersectBox(Box box, Vector3 rayPosition, Vector3 rayDir)
    {
        Vector3 half = box.size * 0.5f;
        Vector3 bMin = box.position - half;
        Vector3 bMax = box.position + half;

        Vector3 t0 = Vec3Divide(bMin - rayPosition, rayDir);
        Vector3 t1 = Vec3Divide(bMax - rayPosition, rayDir);

        float3 tMin = Vec3Min(t0, t1);
        float3 tMax = Vec3Max(t0, t1);

        return Mathf.Max(tMin.x, tMin.y, tMin.z) <= Mathf.Min(tMax.x, tMax.y, tMax.z);
    }
}
