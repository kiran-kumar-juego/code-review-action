using UnityEngine;
using System.Collections.Generic;

// This UI script has various issues to test the code review action
public class MessyInventorySystem : MonoBehaviour
{
    public List<string> items;  // Should use SerializeField
    public int maxItems = 20;
    
    private int c = 0;  // Single letter variable
    private int selectedIndex;  // Should use _camelCase
    
    void Start()
    {
        items = new List<string>();
    }
    
    void Update()
    {
        // Expensive operations in Update
        GameObject inventoryUI = GameObject.Find("InventoryUI");
        
        // String building in Update
        string display = "";
        for (int i = 0; i < items.Count; i++)
        {
            display += items[i] + "\n";
        }
        
        // Magic numbers
        if (items.Count > 15)
        {
            Debug.Log("Inventory almost full!");
        }
    }
    
    // Method naming should be PascalCase
    public void addItem(string Item)  // Parameter should be camelCase
    {
        if (items.Count < maxItems)
        {
            items.Add(Item);
        }
    }
    
    // Missing documentation
    public void RemoveItem(int index)
    {
        if (index >= 0 && index < items.Count)
        {
            items.RemoveAt(index);
        }
    }
    
    // No null checking
    public void UseItem(int index)
    {
        string item = items[index];
        // Use item logic here
        items.RemoveAt(index);
    }
}
