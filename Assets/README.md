# Unity Code Review Action - Sample Project

This sample project demonstrates the Unity Code Review Action by providing examples of both **good** and **bad** Unity C# coding practices.

## 📁 Project Structure

```
SampleProject/
├── Assets/
│   └── Scripts/
│       ├── Player/
│       │   ├── BadPlayerController.cs    ❌ Bad practices example
│       │   └── GoodPlayerController.cs   ✅ Good practices example
│       ├── Managers/
│       │   ├── BadGameManager.cs         ❌ Bad practices example
│       │   └── GoodGameManager.cs        ✅ Good practices example
│       └── UI/
│           ├── MessyInventorySystem.cs   ❌ Bad practices example
│           └── CleanInventorySystem.cs   ✅ Good practices example
```

## 🚨 Issues Demonstrated in "Bad" Examples

### BadPlayerController.cs
- ❌ Public fields instead of SerializeField
- ❌ Poor naming conventions (PascalCase for fields, single-letter variables)
- ❌ Expensive operations in Update (GameObject.Find, FindObjectOfType)
- ❌ String concatenation in Update (creates garbage)
- ❌ Magic numbers without constants
- ❌ Missing null checks
- ❌ Missing XML documentation
- ❌ Missing namespace
- ❌ No interface implementation

### BadGameManager.cs
- ❌ Poor singleton implementation
- ❌ Multiple expensive operations in Update
- ❌ Object instantiation/destruction in Update
- ❌ Missing coroutine cleanup
- ❌ Poor method naming (camelCase instead of PascalCase)
- ❌ Magic numbers everywhere
- ❌ Missing documentation
- ❌ No object pooling

### MessyInventorySystem.cs
- ❌ Public fields without SerializeField
- ❌ Single-letter variables
- ❌ Private fields without underscore prefix
- ❌ GameObject.Find in Update
- ❌ String building in Update loop
- ❌ Missing bounds checking
- ❌ Poor error handling

## ✅ Best Practices Shown in "Good" Examples

### GoodPlayerController.cs
- ✅ Proper namespace usage
- ✅ XML documentation for all public members
- ✅ SerializeField for Unity-exposed fields
- ✅ Proper naming conventions (\_camelCase for private, PascalCase for public)
- ✅ Component caching in Awake
- ✅ Proper region organization
- ✅ Interface implementation
- ✅ Event-driven architecture
- ✅ Null checks and validation
- ✅ Const declarations for magic numbers

### GoodGameManager.cs
- ✅ Proper singleton pattern with lazy initialization
- ✅ Object pooling for performance
- ✅ Coroutine lifecycle management
- ✅ Comprehensive error handling
- ✅ Unity Events for decoupling
- ✅ Proper resource cleanup
- ✅ Extensive documentation
- ✅ Validation of references

### CleanInventorySystem.cs
- ✅ Clean separation of concerns
- ✅ Proper error handling and validation
- ✅ Event-driven updates
- ✅ Resource management
- ✅ Comprehensive public API
- ✅ Inner classes for data organization

## 🧪 Testing the Action

To test the Unity Code Review Action with this sample project:

1. **Copy the sample project** to your Unity project's Assets folder
2. **Run the action** on a pull request that includes these files
3. **Review the output** to see how the action identifies issues

### Expected Results

When the action analyzes the "bad" example files, it should report:
- **🚨 Errors**: Performance issues, interface naming violations
- **⚠️ Warnings**: Naming convention issues, missing SerializeField usage
- **ℹ️ Info**: Missing documentation, region suggestions, design pattern opportunities

The "good" example files should pass with minimal or no issues.

## 🎯 Learning Objectives

This sample project helps developers understand:

1. **Performance Optimization**: Avoid expensive operations in Update loops
2. **Naming Conventions**: Follow C# and Unity naming standards
3. **Code Organization**: Use regions, namespaces, and proper structure
4. **Unity Best Practices**: SerializeField, component caching, object pooling
5. **Architecture Patterns**: Interfaces, events, singletons done right
6. **Documentation**: XML comments for public APIs
7. **Error Handling**: Null checks and validation

## 🔧 Configuration

The action behavior can be customized by modifying the `unity-review-config.yml` file:

- Change rule severities (error → warning → info → disabled)
- Adjust thresholds for file size, complexity, etc.
- Modify naming convention requirements
- Add custom exclude patterns

## 📊 Expected Action Output

When run against this sample project, the action should:
- ✅ Successfully analyze all 6 C# files
- ❌ Fail the workflow due to ERROR-level issues in bad examples
- 📝 Generate detailed reports with specific line numbers and suggestions
- 📈 Show statistics: errors, warnings, suggestions, and file compliance rates

This demonstrates that the Unity Code Review Action is working correctly and effectively identifying code quality issues!
