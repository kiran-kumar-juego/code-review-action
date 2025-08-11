using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Events;

namespace YourProject.Managers
{
    /// <summary>
    /// Game manager implementing proper singleton pattern and best practices
    /// </summary>
    public class GoodGameManager : MonoBehaviour
    {
        #region Singleton Implementation
        
        private static GoodGameManager _instance;
        public static GoodGameManager Instance
        {
            get
            {
                if (_instance == null)
                {
                    _instance = FindObjectOfType<GoodGameManager>();
                    if (_instance == null)
                    {
                        Debug.LogError("GoodGameManager not found in scene!");
                    }
                }
                return _instance;
            }
        }
        
        #endregion
        
        #region Public Properties
        
        public int Score { get; private set; }
        public int Lives { get; private set; } = DEFAULT_LIVES;
        public bool IsGameActive { get; private set; }
        
        #endregion
        
        #region Serialized Fields
        
        [Header("Prefab References")]
        [SerializeField] private GameObject _playerPrefab;
        [SerializeField] private GameObject _enemyPrefab;
        
        [Header("Game Settings")]
        [SerializeField] private float _enemySpawnRate = 2.0f;
        [SerializeField] private int _maxEnemies = 10;
        [SerializeField] private Transform[] _spawnPoints;
        
        #endregion
        
        #region Private Fields
        
        private readonly Queue<GameObject> _enemyPool = new Queue<GameObject>();
        private Coroutine _spawnCoroutine;
        private readonly List<GameObject> _activeEnemies = new List<GameObject>();
        
        private const int DEFAULT_LIVES = 3;
        private const int BONUS_LIFE_SCORE = 1000;
        
        #endregion
        
        #region Unity Methods
        
        private void Awake()
        {
            InitializeSingleton();
        }
        
        private void Start()
        {
            InitializeGame();
        }
        
        #endregion
        
        #region Public Methods
        
        /// <summary>
        /// Adds points to the current score
        /// </summary>
        /// <param name="points">Points to add</param>
        public void AddScore(int points)
        {
            if (!IsGameActive) return;
            
            int previousScore = Score;
            Score += points;
            
            OnScoreChanged?.Invoke(Score);
            
            // Check for bonus life
            if (previousScore / BONUS_LIFE_SCORE < Score / BONUS_LIFE_SCORE)
            {
                AddLife();
            }
        }
        
        /// <summary>
        /// Starts the game session
        /// </summary>
        public void StartGame()
        {
            IsGameActive = true;
            Score = 0;
            Lives = DEFAULT_LIVES;
            
            InitializeObjectPool();
            StartEnemySpawning();
            
            OnGameStarted?.Invoke();
        }
        
        /// <summary>
        /// Ends the current game session
        /// </summary>
        public void EndGame()
        {
            IsGameActive = false;
            StopEnemySpawning();
            ClearActiveEnemies();
            
            OnGameEnded?.Invoke(Score);
        }
        
        #endregion
        
        #region Private Methods
        
        private void InitializeSingleton()
        {
            if (_instance != null && _instance != this)
            {
                Destroy(gameObject);
                return;
            }
            
            _instance = this;
            DontDestroyOnLoad(gameObject);
        }
        
        private void InitializeGame()
        {
            ValidateReferences();
            InitializeObjectPool();
        }
        
        private void ValidateReferences()
        {
            if (_playerPrefab == null)
                Debug.LogError("Player prefab not assigned!");
            
            if (_enemyPrefab == null)
                Debug.LogError("Enemy prefab not assigned!");
            
            if (_spawnPoints == null || _spawnPoints.Length == 0)
                Debug.LogWarning("No spawn points assigned!");
        }
        
        private void InitializeObjectPool()
        {
            // Pre-populate enemy pool
            for (int i = 0; i < _maxEnemies; i++)
            {
                GameObject enemy = Instantiate(_enemyPrefab);
                enemy.SetActive(false);
                _enemyPool.Enqueue(enemy);
            }
        }
        
        private void StartEnemySpawning()
        {
            if (_spawnCoroutine != null)
            {
                StopCoroutine(_spawnCoroutine);
            }
            
            _spawnCoroutine = StartCoroutine(SpawnEnemiesRoutine());
        }
        
        private void StopEnemySpawning()
        {
            if (_spawnCoroutine != null)
            {
                StopCoroutine(_spawnCoroutine);
                _spawnCoroutine = null;
            }
        }
        
        private IEnumerator SpawnEnemiesRoutine()
        {
            var waitTime = new WaitForSeconds(_enemySpawnRate);
            
            while (IsGameActive)
            {
                if (_activeEnemies.Count < _maxEnemies && _enemyPool.Count > 0)
                {
                    SpawnEnemy();
                }
                
                yield return waitTime;
            }
        }
        
        private void SpawnEnemy()
        {
            if (_enemyPool.Count == 0 || _spawnPoints.Length == 0) return;
            
            GameObject enemy = _enemyPool.Dequeue();
            Transform spawnPoint = _spawnPoints[UnityEngine.Random.Range(0, _spawnPoints.Length)];
            
            enemy.transform.position = spawnPoint.position;
            enemy.transform.rotation = spawnPoint.rotation;
            enemy.SetActive(true);
            
            _activeEnemies.Add(enemy);
        }
        
        private void AddLife()
        {
            Lives++;
            OnLivesChanged?.Invoke(Lives);
        }
        
        private void ClearActiveEnemies()
        {
            foreach (GameObject enemy in _activeEnemies)
            {
                if (enemy != null)
                {
                    enemy.SetActive(false);
                    _enemyPool.Enqueue(enemy);
                }
            }
            _activeEnemies.Clear();
        }
        
        #endregion
        
        #region Events
        
        [Header("Events")]
        public UnityEvent OnGameStarted;
        public UnityEvent<int> OnScoreChanged;
        public UnityEvent<int> OnLivesChanged;
        public UnityEvent<int> OnGameEnded;
        
        #endregion
    }
}
