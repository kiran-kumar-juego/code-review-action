using System.Collections;
using UnityEngine;

// This class demonstrates various naming convention violations and Unity anti-patterns
public class BadGameManager : MonoBehaviour
{
    // ❌ BAD: Public static field should be PascalCase, singleton not properly implemented
    public static BadGameManager instance;
    
    // ❌ BAD: Public fields should use PascalCase or be properties with SerializeField
    public int score = 0;
    public int lives = 3;
    public bool gameStarted = false;
    
    // ❌ BAD: Public fields expose internal state, should use SerializeField
    public GameObject playerPrefab;
    public GameObject enemyPrefab;
    
    // ❌ BAD: Private fields should start with underscore
    private int playerCount = 0;
    private float gameTime;
    private bool isPaused;
    
    // ❌ BAD: Constants should be ALL_CAPS
    private const int maxEnemies = 10;
    private const float spawnRate = 2.0f;
    
    void Awake()
    {
        // ❌ BAD: Poor singleton implementation without null checking
        instance = this;
        
        // ❌ BAD: Local variables should use camelCase
        int StartingScore = 0;
        float InitialTime = 0f;
        
        score = StartingScore;
        gameTime = InitialTime;
    }
    
    void Start()
    {
        StartCoroutine(SpawnEnemies());
    }
    
    void Update()
    {
        // ❌ BAD: Multiple expensive operations in Update
        GameObject[] players = GameObject.FindGameObjectsWithTag("Player");
        GameObject[] enemies = GameObject.FindGameObjectsWithTag("Enemy");
        
        // ❌ BAD: String concatenation creating garbage
        string status = "Score: " + score + " Lives: " + lives;
        
        // ❌ BAD: Magic numbers everywhere
        if (score > 1000)
        {
            lives += 1;
        }
        
        if (enemies.Length > 10)
        {
            // ❌ BAD: Destroying objects in Update
            for (int i = 5; i < enemies.Length; i++)
            {
                Destroy(enemies[i]);
            }
        }
    }
    
    // ❌ BAD: Method should use PascalCase
    public void addScore(int Points)  // ❌ Parameter should be camelCase
    {
        // ❌ BAD: Local variable should be camelCase
        int BonusPoints = 0;
        
        if (Points > 100)
        {
            BonusPoints = 50;
        }
        
        score += Points + BonusPoints;
    }
    
    // ❌ BAD: Method should use PascalCase, missing documentation
    public void startGame()
    {
        gameStarted = true;
        
        // ❌ BAD: Local variables should be camelCase
        int PlayerStartHealth = 100;
        float GameDuration = 300f;
    }
    
    // ❌ BAD: Missing coroutine cleanup, no documentation
    IEnumerator SpawnEnemies()
    {
        while (true)
        {
            // ❌ BAD: Instantiating in Update-like loop without object pooling
            Instantiate(enemyPrefab, Random.insideUnitSphere * 10, Quaternion.identity);
            yield return null;  // ❌ BAD: Should use WaitForSeconds
        }
        // ❌ BAD: This coroutine never stops
    }
    
    // ❌ BAD: No documentation, no proper cleanup
    public void EndGame()
    {
        gameStarted = false;
        // ❌ BAD: No coroutine cleanup, potential memory leak
    }
}
