using System;
using UnityEngine;

// This script has multiple issues for testing the code review action
public class BadPlayerController : MonoBehaviour
{
    public int health = 100;  // Should use SerializeField instead of public
    public Transform Target;  // Bad naming - should be camelCase for public fields or use SerializeField
    public float Speed = 5.0f;
    
    private int x = 0;  // Single letter variable name - bad practice
    private int damage;  // Should use _camelCase for private fields
    
    void Start()
    {
        // Missing null checks
        Target.position = Vector3.zero;
    }
    
    void Update()
    {
        // Expensive operations in Update - bad for performance
        GameObject enemy = GameObject.Find("Enemy");
        GameObject.FindObjectOfType<Enemy>();
        
        // String concatenation in Update - creates garbage
        string message = "Health: " + health + " Speed: " + Speed;
        
        // Magic numbers
        if (health < 50)
        {
            Speed = 2.5f;
        }
        
        // Instantiation in Update - bad practice
        if (Input.GetKeyDown(KeyCode.Space))
        {
            Instantiate(enemy);
        }
    }
    
    // Method should be PascalCase
    public void takeDamage(int Amount)  // Parameter should be camelCase
    {
        health -= Amount;
        if (health <= 0)
        {
            Destroy(gameObject);
        }
    }
    
    // Missing XML documentation for public method
    public void Heal(int amount)
    {
        health += amount;
        if (health > 100) health = 100;
    }
}

// Missing interface - could implement IHealth interface
public class Enemy : MonoBehaviour
{
    public int Health = 100;
}
