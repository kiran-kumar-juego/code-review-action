# C# Naming Conventions for Unity Projects

This document outlines the naming conventions enforced by the Unity Code Analyzer.

## 📋 **Naming Convention Rules**

### 1. **Local Variables (camelCase)**
Variables declared within methods should start with a lowercase letter.

```csharp
// ✅ Correct
void PlayerAction()
{
    int health = 100;           // Local variable
    float moveSpeed = 5.5f;     // Local variable
    string playerName = "Hero"; // Local variable
}

// ❌ Incorrect
void PlayerAction()
{
    int Health = 100;           // Should be camelCase
    float MoveSpeed = 5.5f;     // Should be camelCase
}
```

### 2. **Constants (ALL_CAPS)**
Constants should be written in all uppercase letters with underscores.

```csharp
// ✅ Correct
const int MAX_HEALTH = 100;
const string PLAYER_NAME = "DefaultPlayer";
const float GRAVITY_FORCE = 9.81f;

// ❌ Incorrect
const int maxHealth = 100;     // Should be ALL_CAPS
const string playerName = "DefaultPlayer"; // Should be ALL_CAPS
```

### 3. **Member Variables (_underscore prefix)**
Class member variables should start with an underscore.

```csharp
public class PlayerController : MonoBehaviour
{
    // ✅ Correct
    private int _count = 5;           // Member variable with underscore
    private float _health;            // Member variable with underscore
    private string _playerName;       // Member variable with underscore
    
    // ❌ Incorrect
    private int count = 5;            // Should have underscore prefix
    private float health;             // Should have underscore prefix
}
```

### 4. **Global/Module Variables (PascalCase)**
Public properties and global variables should use PascalCase.

```csharp
public class GameManager : MonoBehaviour
{
    // ✅ Correct
    public int Score = 100;           // Global/public variable
    public static GameManager Instance; // Global static variable
    public bool IsGameActive { get; set; } // Property
    
    // ❌ Incorrect
    public int score = 100;           // Should be PascalCase
    public static GameManager instance; // Should be PascalCase
}
```

### 5. **Methods (PascalCase)**
Methods should start with a capital letter.

```csharp
// ✅ Correct
public void StartGame() { }
public bool AddItem(string itemName) { }
private void UpdateHealth(int value) { }

// ❌ Incorrect
public void startGame() { }           // Should be PascalCase
public bool addItem(string itemName) { } // Should be PascalCase
```

### 6. **Parameters (camelCase)**
Method parameters should use camelCase.

```csharp
// ✅ Correct
public void MovePlayer(float speed, Vector3 direction) { }
public bool AddItem(string itemName, int quantity) { }

// ❌ Incorrect
public void MovePlayer(float Speed, Vector3 Direction) { } // Should be camelCase
public bool AddItem(string ItemName, int Quantity) { }     // Should be camelCase
```

### 7. **Classes (PascalCase)**
Class names should use PascalCase and be descriptive of their purpose.

```csharp
// ✅ Correct - Basic PascalCase
public class PlayerController { }
public class InventorySystem { }
public class GameManager { }

// ✅ Correct - Unity-specific patterns
public class PlayerController : MonoBehaviour { }
public class WeaponData : ScriptableObject { }
public class GameSettings : ScriptableObject { }
public class Singleton<T> : MonoBehaviour where T : Component { }

// ✅ Correct - Specialized Unity classes
public class PlayerMovement : MonoBehaviour { }
public class EnemyAI : MonoBehaviour { }
public class UIManager : MonoBehaviour { }
public class AudioManager : Singleton<AudioManager> { }

// ❌ Incorrect - Naming violations
public class playerController { }     // Should start with capital letter
public class player_controller { }   // Should not use underscores
public class PLAYERCONTROLLER { }    // Should not be all caps
public class PC { }                   // Should be descriptive, not abbreviated
```

#### Unity-Specific Class Naming Guidelines

| Class Type | Pattern | Example | Best Practice |
|------------|---------|---------|---------------|
| **MonoBehaviour Components** | `PascalCase + Descriptor` | `PlayerController`, `EnemyAI` | Use descriptive names ending with Controller, Manager, etc. |
| **ScriptableObject Data** | `PascalCase + Data/Settings` | `WeaponData`, `GameSettings` | Clearly indicate it's a data container |
| **Singleton Managers** | `PascalCase + Manager` | `GameManager`, `AudioManager` | Use Manager suffix for global systems |
| **UI Components** | `PascalCase + UI + Purpose` | `UIHealthBar`, `UIMainMenu` | Prefix with UI for interface elements |
| **Abstract Classes** | `PascalCase + Base/Abstract` | `BaseWeapon`, `AbstractEnemy` | Indicate inheritance purpose |

#### Common Class Naming Mistakes to Avoid

❌ **Don't do this:**
```csharp
public class playerController { }      // Lowercase start
public class player_controller { }    // Underscores
public class PLAYERCONTROLLER { }     // All caps  
public class pController { }          // Abbreviated
public class Player_Controller { }    // Mixed case with underscore
```

✅ **Do this instead:**
```csharp
public class PlayerController : MonoBehaviour { }
public class InventoryManager : MonoBehaviour { }
public class WeaponData : ScriptableObject { }
public class GameSettings : ScriptableObject { }
public class UIHealthDisplay : MonoBehaviour { }
```

## 🎯 **Complete Example**

Here's a comprehensive example showing all naming conventions:

```csharp
public class PlayerController : MonoBehaviour
{
    // Constants (ALL_CAPS)
    private const int MAX_HEALTH = 100;
    private const string DEFAULT_PLAYER_NAME = "Player";
    
    // Member variables (_underscore prefix)
    private int _currentHealth;
    private float _moveSpeed;
    private string _playerName;
    
    // Public properties (PascalCase)
    public int Score { get; private set; }
    public bool IsAlive { get; private set; }
    
    // Public fields for Unity Inspector (PascalCase)
    [SerializeField] private float JumpForce = 10f;
    
    // Methods (PascalCase)
    public void StartGame()
    {
        // Local variables (camelCase)
        int startingHealth = MAX_HEALTH;
        float initialSpeed = 5.0f;
        string defaultName = DEFAULT_PLAYER_NAME;
        
        // Initialize member variables
        _currentHealth = startingHealth;
        _moveSpeed = initialSpeed;
        _playerName = defaultName;
        
        IsAlive = true;
        Score = 0;
    }
    
    // Parameters (camelCase)
    public void TakeDamage(int damageAmount, string damageType)
    {
        // Local variables (camelCase)
        int newHealth = _currentHealth - damageAmount;
        
        _currentHealth = Mathf.Max(0, newHealth);
        
        if (_currentHealth <= 0)
        {
            IsAlive = false;
        }
    }
    
    public void AddScore(int points)
    {
        Score += points;
    }
}
```

## 🔧 **Unity Analyzer Detection**

The Unity Code Analyzer will detect and report violations of these conventions:

- **Critical Issues**: Naming convention violations that affect code readability
- **Detailed Reports**: Line-by-line analysis with specific recommendations
- **Best Practice Guidelines**: Suggestions for improving code quality

## 📚 **Additional Resources**

- [Microsoft C# Naming Guidelines](https://docs.microsoft.com/en-us/dotnet/standard/design-guidelines/naming-guidelines)
- [Unity Code Style Guidelines](https://unity.com/how-to/naming-and-code-style-tips-c-scripting-unity)
