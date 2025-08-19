using System;
using UnityEngine;

// This script demonstrates multiple naming convention violations and Unity anti-patterns
public class BadPlayerController : MonoBehaviour
{
    // ❌ BAD: Public fields should use SerializeField, not expose internal state
    public int health = 100;
    public Transform Target;  // ❌ Should be camelCase for parameters or use SerializeField
    public float Speed = 5.0f;
    
    // ❌ BAD: Private fields should use underscore prefix
    private int x = 0;  // ❌ Also: single letter variable names
    private int damage;
    private bool isAlive;
    private float moveSpeed;
    
    // ❌ BAD: Constants should be ALL_CAPS
    private const int maxHealth = 100;
    private const float jumpForce = 10f;
    
    void Start()
    {
        // ❌ BAD: Local variables should be camelCase
        int StartingHealth = maxHealth;
        float InitialSpeed = 5.0f;
        bool CanMove = true;
        
        health = StartingHealth;
        Speed = InitialSpeed;
        
        // ❌ BAD: Missing null checks
        Target.position = Vector3.zero;
    }
    
    void Update()
    {
        // ❌ BAD: Expensive operations in Update - performance killer
        GameObject enemy = GameObject.Find("Enemy");
        GameObject.FindObjectOfType<Enemy>();
        
        // ❌ BAD: String concatenation in Update - creates garbage
        string message = "Health: " + health + " Speed: " + Speed;
        
        // ❌ BAD: Magic numbers
        if (health < 50)
        {
            // ❌ BAD: Local variable should be camelCase
            float PanicSpeed = Speed * 2;
            moveSpeed = PanicSpeed;
        }
        
        // ❌ BAD: More expensive operations
        Camera.main.transform.position = transform.position;
        
        // ❌ BAD: Instantiation in Update - bad practice
        if (Input.GetKeyDown(KeyCode.Space))
        {
            Instantiate(enemy);
        }
    }
    
    // ❌ BAD: Method should use PascalCase
    public void takeDamage(int Amount)  // ❌ Parameter should be camelCase
    {
        // ❌ BAD: Local variables should be camelCase
        int RemainingHealth = health - Amount;
        bool WillDie = RemainingHealth <= 0;
        
        health = RemainingHealth;
        
        if (WillDie)
        {
            Destroy(gameObject);
        }
    }
    
    // ❌ BAD: Method should use PascalCase, missing documentation
    public void Heal(int amount)
    {
        // ❌ BAD: Local variable should be camelCase
        int NewHealth = health + amount;
        health = NewHealth;
        
        // ❌ BAD: Magic number
        if (health > 100) health = 100;
    }
    
    // ❌ BAD: Method should use PascalCase
    private void movePlayer(float Speed)  // ❌ Parameter should be camelCase
    {
        // ❌ BAD: Local variables should be camelCase
        Vector3 NewPosition = transform.position;
        float DeltaTime = Time.deltaTime;
        
        NewPosition += Vector3.forward * Speed * DeltaTime;
        transform.position = NewPosition;
    }
}

// ❌ BAD: Class should use PascalCase, missing documentation
public class enemy : MonoBehaviour
{
    // ❌ BAD: Public field exposure, should use properties
    public int enemyHealth = 50;
    public float attackDamage = 10f;
    
    // ❌ BAD: Private fields should have underscore prefix
    private bool isAttacking;
    private float lastAttackTime;
    
    // ❌ BAD: Constants should be ALL_CAPS
    private const float attackCooldown = 2.0f;
}
