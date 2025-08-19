using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

// ❌ BAD: Class should have proper documentation
public class MessyInventorySystem : MonoBehaviour
{
    // ❌ BAD: Public field exposure, should use SerializeField
    public List<Item> Items;
    public Transform Content;
    public GameObject ItemPrefab;
    public Button AddButton;
    
    // ❌ BAD: Private fields should have underscore prefix
    private Dictionary<string, Item> itemCache;
    private bool isDirty;
    private int maxItems;
    private float updateTimer;
    private int c = 0;  // ❌ Single letter variable
    
    // ❌ BAD: Constants should be ALL_CAPS
    private const int defaultMaxItems = 50;
    private const float refreshRate = 0.1f;
    
    // ❌ BAD: Event should use PascalCase
    public event System.Action<Item> onItemAdded;
    
    void Start()
    {
        // ❌ BAD: Local variables should be camelCase
        int StartingCapacity = defaultMaxItems;
        bool CanAddItems = true;
        float UpdateInterval = refreshRate;
        
        maxItems = StartingCapacity;
        isDirty = CanAddItems;
        updateTimer = UpdateInterval;
        
        // ❌ BAD: Direct assignment without null check
        Items = new List<Item>();
        itemCache = new Dictionary<string, Item>();
        
        // ❌ BAD: Missing null check
        AddButton.onClick.AddListener(AddRandomItem);
    }
    
    void Update()
    {
        // ❌ BAD: Expensive operations in Update
        UpdateInventoryDisplay();
        
        // ❌ BAD: String concatenation in Update
        string DebugInfo = "Items: " + Items.Count + " Max: " + maxItems;
        
        // ❌ BAD: Finding objects every frame
        GameObject InventoryPanel = GameObject.Find("InventoryPanel");
        Canvas MainCanvas = GameObject.FindObjectOfType<Canvas>();
        
        // ❌ BAD: Local variables should be camelCase
        float DeltaTime = Time.deltaTime;
        updateTimer += DeltaTime;
        
        // ❌ BAD: Magic number
        if (updateTimer > 0.1f)
        {
            // ❌ BAD: Expensive operation
            RefreshAllItems();
            updateTimer = 0f;
        }
    }
    
    // ❌ BAD: Method should use PascalCase
    public void addItem(Item NewItem)  // ❌ Parameter should be camelCase
    {
        // ❌ BAD: Local variables should be camelCase
        bool CanAdd = Items.Count < maxItems;
        string ItemKey = NewItem.name;
        
        if (CanAdd)
        {
            Items.Add(NewItem);
            itemCache[ItemKey] = NewItem;
            
            // ❌ BAD: Null check after usage
            if (onItemAdded != null)
                onItemAdded(NewItem);
        }
    }
    
    // ❌ BAD: Method should use PascalCase
    private void AddRandomItem()
    {
        // ❌ BAD: Local variables should be camelCase
        Item RandomItem = new Item();
        string ItemName = "Item_" + Items.Count;
        int ItemValue = UnityEngine.Random.Range(1, 100);
        
        RandomItem.name = ItemName;
        RandomItem.value = ItemValue;
        
        addItem(RandomItem);
    }
    
    // ❌ BAD: Method should use PascalCase
    private void UpdateInventoryDisplay()
    {
        // ❌ BAD: Expensive operation called every frame
        foreach (Transform Child in Content)
        {
            if (Child != Content)
            {
                // ❌ BAD: Destroying objects in Update
                Destroy(Child.gameObject);
            }
        }
        
        // ❌ BAD: Instantiating objects in Update
        foreach (Item CurrentItem in Items)
        {
            // ❌ BAD: Local variable should be camelCase
            GameObject NewItemUI = Instantiate(ItemPrefab, Content);
            Text ItemText = NewItemUI.GetComponent<Text>();
            
            // ❌ BAD: String concatenation
            ItemText.text = CurrentItem.name + " - Value: " + CurrentItem.value;
        }
    }
    
    // ❌ BAD: Method should use PascalCase
    private void RefreshAllItems()
    {
        // ❌ BAD: Creating garbage in tight loop
        for (int Index = 0; Index < Items.Count; Index++)  // ❌ Local variable should be camelCase
        {
            // ❌ BAD: String operations in loop
            string UpdatedName = "Updated_" + Items[Index].name;
            Items[Index].name = UpdatedName;
        }
    }
}

// ❌ BAD: Class should use PascalCase (though this one is correct, adding violations)
[System.Serializable]
public class Item
{
    // ❌ BAD: Public fields should follow proper naming conventions
    public string name;
    public int value;
    public Sprite Icon;  // ❌ Should be camelCase for public fields or use properties
    
    // ❌ BAD: Constants should be ALL_CAPS
    public const int maxValue = 1000;
}
