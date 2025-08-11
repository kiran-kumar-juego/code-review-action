using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

namespace YourProject.UI
{
    /// <summary>
    /// Clean inventory system demonstrating proper Unity UI practices
    /// </summary>
    public class CleanInventorySystem : MonoBehaviour
    {
        #region Unity Methods
        
        private void Awake()
        {
            InitializeComponents();
        }
        
        private void Start()
        {
            InitializeInventory();
        }
        
        #endregion
        
        #region Public Properties
        
        /// <summary>
        /// Current number of items in inventory
        /// </summary>
        public int ItemCount => _items.Count;
        
        /// <summary>
        /// Maximum capacity of the inventory
        /// </summary>
        public int MaxCapacity => _maxItems;
        
        /// <summary>
        /// Whether the inventory is full
        /// </summary>
        public bool IsFull => _items.Count >= _maxItems;
        
        #endregion
        
        #region Serialized Fields
        
        [Header("Inventory Settings")]
        [SerializeField] private int _maxItems = 20;
        [SerializeField] private Transform _itemContainer;
        [SerializeField] private GameObject _itemUIPrefab;
        
        [Header("UI References")]
        [SerializeField] private Text _inventoryCountText;
        [SerializeField] private Button _clearAllButton;
        
        #endregion
        
        #region Private Fields
        
        private readonly List<InventoryItem> _items = new List<InventoryItem>();
        private readonly List<GameObject> _itemUIElements = new List<GameObject>();
        private int _selectedIndex = -1;
        
        private const string INVENTORY_FULL_MESSAGE = "Inventory is full!";
        private const string ITEM_USED_MESSAGE = "Used item: {0}";
        
        #endregion
        
        #region Public Methods
        
        /// <summary>
        /// Attempts to add an item to the inventory
        /// </summary>
        /// <param name="itemName">Name of the item to add</param>
        /// <returns>True if item was added successfully</returns>
        public bool AddItem(string itemName)
        {
            if (string.IsNullOrEmpty(itemName))
            {
                Debug.LogWarning("Cannot add item with null or empty name");
                return false;
            }
            
            if (IsFull)
            {
                Debug.LogWarning(INVENTORY_FULL_MESSAGE);
                OnInventoryFull?.Invoke();
                return false;
            }
            
            var newItem = new InventoryItem(itemName, DateTime.Now);
            _items.Add(newItem);
            
            CreateItemUI(newItem);
            UpdateInventoryDisplay();
            
            OnItemAdded?.Invoke(newItem);
            return true;
        }
        
        /// <summary>
        /// Removes an item at the specified index
        /// </summary>
        /// <param name="index">Index of item to remove</param>
        /// <returns>True if item was removed successfully</returns>
        public bool RemoveItem(int index)
        {
            if (!IsValidIndex(index))
            {
                Debug.LogWarning($"Invalid inventory index: {index}");
                return false;
            }
            
            InventoryItem removedItem = _items[index];
            _items.RemoveAt(index);
            
            DestroyItemUI(index);
            UpdateInventoryDisplay();
            
            OnItemRemoved?.Invoke(removedItem);
            return true;
        }
        
        /// <summary>
        /// Uses an item at the specified index
        /// </summary>
        /// <param name="index">Index of item to use</param>
        /// <returns>True if item was used successfully</returns>
        public bool UseItem(int index)
        {
            if (!IsValidIndex(index))
            {
                Debug.LogWarning($"Invalid inventory index: {index}");
                return false;
            }
            
            InventoryItem usedItem = _items[index];
            Debug.Log(string.Format(ITEM_USED_MESSAGE, usedItem.Name));
            
            bool removed = RemoveItem(index);
            if (removed)
            {
                OnItemUsed?.Invoke(usedItem);
            }
            
            return removed;
        }
        
        /// <summary>
        /// Clears all items from the inventory
        /// </summary>
        public void ClearInventory()
        {
            _items.Clear();
            ClearItemUI();
            UpdateInventoryDisplay();
            
            OnInventoryCleared?.Invoke();
        }
        
        #endregion
        
        #region Private Methods
        
        private void InitializeComponents()
        {
            if (_clearAllButton != null)
            {
                _clearAllButton.onClick.AddListener(ClearInventory);
            }
        }
        
        private void InitializeInventory()
        {
            ValidateReferences();
            UpdateInventoryDisplay();
        }
        
        private void ValidateReferences()
        {
            if (_itemContainer == null)
                Debug.LogError("Item container not assigned!");
                
            if (_itemUIPrefab == null)
                Debug.LogError("Item UI prefab not assigned!");
                
            if (_inventoryCountText == null)
                Debug.LogWarning("Inventory count text not assigned");
        }
        
        private bool IsValidIndex(int index)
        {
            return index >= 0 && index < _items.Count;
        }
        
        private void CreateItemUI(InventoryItem item)
        {
            if (_itemUIPrefab == null || _itemContainer == null) return;
            
            GameObject itemUI = Instantiate(_itemUIPrefab, _itemContainer);
            
            // Configure item UI (assuming it has a Text component)
            Text itemText = itemUI.GetComponentInChildren<Text>();
            if (itemText != null)
            {
                itemText.text = item.Name;
            }
            
            _itemUIElements.Add(itemUI);
        }
        
        private void DestroyItemUI(int index)
        {
            if (index >= 0 && index < _itemUIElements.Count)
            {
                GameObject uiElement = _itemUIElements[index];
                if (uiElement != null)
                {
                    Destroy(uiElement);
                }
                _itemUIElements.RemoveAt(index);
            }
        }
        
        private void ClearItemUI()
        {
            foreach (GameObject uiElement in _itemUIElements)
            {
                if (uiElement != null)
                {
                    Destroy(uiElement);
                }
            }
            _itemUIElements.Clear();
        }
        
        private void UpdateInventoryDisplay()
        {
            if (_inventoryCountText != null)
            {
                _inventoryCountText.text = $"{ItemCount}/{MaxCapacity}";
            }
        }
        
        #endregion
        
        #region Events
        
        public event Action<InventoryItem> OnItemAdded;
        public event Action<InventoryItem> OnItemRemoved;
        public event Action<InventoryItem> OnItemUsed;
        public event Action OnInventoryFull;
        public event Action OnInventoryCleared;
        
        #endregion
        
        #region Inner Classes
        
        /// <summary>
        /// Represents an item in the inventory
        /// </summary>
        [System.Serializable]
        public class InventoryItem
        {
            public string Name { get; private set; }
            public DateTime DateAdded { get; private set; }
            
            public InventoryItem(string name, DateTime dateAdded)
            {
                Name = name;
                DateAdded = dateAdded;
            }
        }
        
        #endregion
    }
}
