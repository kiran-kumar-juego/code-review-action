using System;
using UnityEngine;

namespace YourProject.Player
{
    /// <summary>
    /// A good example of a properly structured player controller with best practices
    /// </summary>
    public class GoodPlayerController : MonoBehaviour, IHealth
    {
        #region Unity Methods
        
        private void Awake()
        {
            _playerTransform = transform;
            _rigidbody = GetComponent<Rigidbody>();
        }
        
        private void Start()
        {
            InitializePlayer();
        }
        
        private void Update()
        {
            HandleInput();
        }
        
        #endregion
        
        #region Public Properties
        
        /// <summary>
        /// Current health of the player
        /// </summary>
        public int Health { get; private set; } = MAX_HEALTH;
        
        /// <summary>
        /// Whether the player is currently alive
        /// </summary>
        public bool IsAlive => Health > 0;
        
        #endregion
        
        #region Private Fields
        
        [SerializeField] private float _moveSpeed = 5.0f;
        [SerializeField] private float _jumpForce = 10.0f;
        [SerializeField] private Transform _spawnPoint;
        
        private Transform _playerTransform;
        private Rigidbody _rigidbody;
        private bool _isGrounded;
        
        private const int MAX_HEALTH = 100;
        private const float MIN_SPEED = 1.0f;
        
        #endregion
        
        #region Public Methods
        
        /// <summary>
        /// Applies damage to the player
        /// </summary>
        /// <param name="damageAmount">Amount of damage to apply</param>
        public void TakeDamage(int damageAmount)
        {
            if (!IsAlive) return;
            
            Health = Mathf.Max(0, Health - damageAmount);
            
            OnHealthChanged?.Invoke(Health);
            
            if (!IsAlive)
            {
                OnPlayerDeath?.Invoke();
            }
        }
        
        /// <summary>
        /// Heals the player by the specified amount
        /// </summary>
        /// <param name="healAmount">Amount to heal</param>
        public void Heal(int healAmount)
        {
            if (!IsAlive) return;
            
            Health = Mathf.Min(MAX_HEALTH, Health + healAmount);
            OnHealthChanged?.Invoke(Health);
        }
        
        #endregion
        
        #region Private Methods
        
        private void InitializePlayer()
        {
            if (_spawnPoint != null)
            {
                _playerTransform.position = _spawnPoint.position;
            }
            
            Health = MAX_HEALTH;
        }
        
        private void HandleInput()
        {
            float horizontal = Input.GetAxis("Horizontal");
            float vertical = Input.GetAxis("Vertical");
            
            Vector3 movement = new Vector3(horizontal, 0, vertical) * _moveSpeed * Time.deltaTime;
            _playerTransform.Translate(movement);
            
            if (Input.GetKeyDown(KeyCode.Space) && _isGrounded)
            {
                Jump();
            }
        }
        
        private void Jump()
        {
            if (_rigidbody != null)
            {
                _rigidbody.AddForce(Vector3.up * _jumpForce, ForceMode.Impulse);
            }
        }
        
        #endregion
        
        #region Events
        
        public event Action<int> OnHealthChanged;
        public event Action OnPlayerDeath;
        
        #endregion
    }
    
    /// <summary>
    /// Interface for objects that can take damage and be healed
    /// </summary>
    public interface IHealth
    {
        int Health { get; }
        bool IsAlive { get; }
        void TakeDamage(int damageAmount);
        void Heal(int healAmount);
    }
}
