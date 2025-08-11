using System.Collections;
using UnityEngine;

// This class demonstrates various issues with Unity best practices
public class BadGameManager : MonoBehaviour
{
    public static BadGameManager instance;  // Singleton without proper implementation
    
    public int score = 0;
    public int lives = 3;
    public bool gameStarted = false;
    
    public GameObject playerPrefab;
    public GameObject enemyPrefab;
    
    void Awake()
    {
        // Poor singleton implementation
        instance = this;
    }
    
    void Start()
    {
        StartCoroutine(SpawnEnemies());
    }
    
    void Update()
    {
        // Multiple expensive operations in Update
        GameObject[] players = GameObject.FindGameObjectsWithTag("Player");
        GameObject[] enemies = GameObject.FindGameObjectsWithTag("Enemy");
        
        // String concatenation creating garbage
        string status = "Score: " + score + " Lives: " + lives;
        
        // Magic numbers everywhere
        if (score > 1000)
        {
            lives += 1;
        }
        
        if (enemies.Length > 10)
        {
            // Destroying objects in Update
            for (int i = 5; i < enemies.Length; i++)
            {
                Destroy(enemies[i]);
            }
        }
    }
    
    // Method naming should be PascalCase
    public void addScore(int points)
    {
        score += points;
    }
    
    // Missing coroutine cleanup
    IEnumerator SpawnEnemies()
    {
        while (true)
        {
            // Instantiating in coroutine without object pooling
            Instantiate(enemyPrefab, Random.insideUnitSphere * 10, Quaternion.identity);
            yield return null;  // Should use WaitForSeconds or similar
        }
    }
    
    // Method should be documented
    public void EndGame()
    {
        gameStarted = false;
        // No coroutine cleanup
    }
}
