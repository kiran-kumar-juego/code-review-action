#!/bin/bash

# Function to parse YAML arrays
parse_yaml_array() {
    local file="$1"
    local section="$2"
    local key="$3"
    if [ -f "$file" ]; then
        # Handle different sections correctly
        if [[ "$section" == "file_patterns" && "$key" == "include" ]]; then
            awk '
            BEGIN { found_section=0; found_key=0 }
            /^file_patterns:/ { found_section=1; next }
            found_section && /^  include:/ { found_key=1; next }
            found_key && /^    -/ { 
                gsub(/^    - /, ""); 
                gsub(/"/, ""); 
                gsub(/'\''/, "");
                if (length($0) > 0) print $0
                next
            }
            found_key && /^  [a-zA-Z_]/ && !/^    / { found_key=0 }
            found_key && /^[a-zA-Z_]/ { found_section=0; found_key=0 }
            ' "$file"
        elif [[ "$section" == "file_patterns" && "$key" == "exclude" ]]; then
            awk '
            BEGIN { found_section=0; found_key=0 }
            /^file_patterns:/ { found_section=1; next }
            found_section && /^  exclude:/ { found_key=1; next }
            found_key && /^    -/ { 
                gsub(/^    - /, ""); 
                gsub(/"/, ""); 
                gsub(/'\''/, "");
                if (length($0) > 0) print $0
                next
            }
            found_key && /^  [a-zA-Z_]/ && !/^    / { found_key=0 }
            found_key && /^[a-zA-Z_]/ { found_section=0; found_key=0 }
            ' "$file"
        fi
    fi
}

# This script performs detailed analysis of Unity C# scripts for common issues and best practices

set -e

# Configuration file path
CONFIG_FILE="${CONFIG_FILE:-"$(dirname "$0")/../unity-review-config.yml"}"

# Function to parse YAML values (simple parser for our needs)
parse_yaml() {
    local file="$1"
    local key="$2"
    if [ -f "$file" ]; then
        grep -E "^\s*${key}:" "$file" | sed -E "s/^\s*${key}:\s*//" | sed 's/["'"'"']//g' | xargs
    fi
}

# Function to get rule severity
get_rule_severity() {
    local rule_category="$1"
    local rule_name="$2"
    if [ -f "$CONFIG_FILE" ]; then
        awk -v cat="$rule_category" -v rule="$rule_name" '
        BEGIN { in_rules=0; in_category=0 }
        /^rules:/ { in_rules=1; next }
        in_rules && /^[[:space:]]*[a-zA-Z]/ && $0 !~ "^[[:space:]]*" cat { in_category=0 }
        in_rules && $0 ~ "^[[:space:]]*" cat ":" { in_category=1; next }
        in_category && $0 ~ "^[[:space:]]*" rule ":" { 
            gsub(/^[[:space:]]*[^:]*:[[:space:]]*/, ""); 
            gsub(/"/, ""); 
            print; 
            exit 
        }
        ' "$CONFIG_FILE" | xargs
    fi
}

# Function to get threshold values
get_threshold() {
    local threshold_name="$1"
    if [ -f "$CONFIG_FILE" ]; then
        awk -v thresh="$threshold_name" '
        BEGIN { in_thresholds=0 }
        /^thresholds:/ { in_thresholds=1; next }
        in_thresholds && /^[[:space:]]*[a-zA-Z]/ && $0 ~ "^[[:space:]]*" thresh ":" { 
            gsub(/^[[:space:]]*[^:]*:[[:space:]]*/, ""); 
            print; 
            exit 
        }
        in_thresholds && /^[a-zA-Z]/ { in_thresholds=0 }
        ' "$CONFIG_FILE"
    fi
}

# Load configuration
if [ -f "$CONFIG_FILE" ]; then
    echo "📋 Loading configuration from: $CONFIG_FILE"
    
    # Get namespace prefix  
    NAMESPACE_PREFIX=$(awk '
    BEGIN { found_project=0 }
    /^project:/ { found_project=1; next }
    found_project && /^  namespace_prefix:/ { 
        gsub(/^  namespace_prefix:[[:space:]]*/, ""); 
        gsub(/"/, ""); 
        gsub(/'\''/, "");
        print; 
        exit 
    }
    found_project && /^[a-zA-Z]/ { found_project=0 }
    ' "$CONFIG_FILE")
    NAMESPACE_PREFIX=${NAMESPACE_PREFIX:-"YourProject"}
    
    # Get thresholds
    MAX_GETCOMPONENT_CALLS=$(get_threshold "max_getcomponent_calls")
    MAX_GETCOMPONENT_CALLS=${MAX_GETCOMPONENT_CALLS:-3}
    
    SUGGEST_REGIONS_LINES=$(get_threshold "suggest_regions_lines")
    SUGGEST_REGIONS_LINES=${SUGGEST_REGIONS_LINES:-100}
    
    FILE_SIZE_LINES=$(get_threshold "file_size_lines")
    FILE_SIZE_LINES=${FILE_SIZE_LINES:-300}
    
    echo "✅ Configuration loaded successfully"
else
    echo "⚠️ Configuration file not found at: $CONFIG_FILE"
    echo "Using default settings..."
    NAMESPACE_PREFIX="YourProject"
    MAX_GETCOMPONENT_CALLS=3
    SUGGEST_REGIONS_LINES=100
    FILE_SIZE_LINES=300
fi
echo ""

# Function to get files based on configuration patterns
get_files_to_analyze() {
    local temp_file="$TMPDIR/files_to_analyze.tmp"
    local exclude_file="$TMPDIR/exclude_patterns.tmp"
    
    # Get include patterns from config or use default
    if [ -f "$CONFIG_FILE" ]; then
        parse_yaml_array "$CONFIG_FILE" "file_patterns" "include" > "$temp_file"
    fi
    
    # If no patterns in config or config not found, use default
    if [ ! -s "$temp_file" ]; then
        echo "Assets/**/*.cs" > "$temp_file"
    fi
    
    # Get exclude patterns
    if [ -f "$CONFIG_FILE" ]; then
        parse_yaml_array "$CONFIG_FILE" "file_patterns" "exclude" > "$exclude_file"
    fi
    
    # Find files matching include patterns
    local all_files="$TMPDIR/all_matching_files.tmp"
    : > "$all_files"  # Clear file
    
    while IFS= read -r pattern; do
        if [ ! -z "$pattern" ] && [[ "$pattern" == *"*.cs" ]]; then
            # Convert glob pattern to find command
            local find_path="${pattern%/*}"
            local find_name="${pattern##*/}"
            
            # Handle Assets/**/*.cs pattern
            if [[ "$find_path" == "Assets/**" ]]; then
                find Assets/ -name "$find_name" -type f 2>/dev/null >> "$all_files"
            elif [[ "$find_path" == "Assets" ]]; then
                find Assets/ -maxdepth 1 -name "$find_name" -type f 2>/dev/null >> "$all_files"
            else
                # Handle other patterns
                if [ -d "${find_path%/*}" ]; then
                    find "${find_path%/*}" -name "$find_name" -type f 2>/dev/null >> "$all_files"
                fi
            fi
        fi
    done < "$temp_file"
    
    # Filter out excluded files using proper glob pattern matching
    local final_files="$TMPDIR/final_files.tmp"
    : > "$final_files"  # Clear file
    
    if [ -s "$exclude_file" ]; then
        while IFS= read -r file; do
            local should_exclude=false
            while IFS= read -r exclude_pattern; do
                if [ ! -z "$exclude_pattern" ]; then
                    # Convert glob pattern to regex-like matching
                    case "$exclude_pattern" in
                        # Handle directory/** patterns (recursive directory matching)
                        *"/**")
                            local dir_pattern="${exclude_pattern%/**}"
                            if [[ "$file" == "$dir_pattern"/* ]] || [[ "$file" == "$dir_pattern" ]]; then
                                should_exclude=true
                                break
                            fi
                            ;;
                        # Handle **/*.ext patterns (recursive file matching with extension)
                        "**/*."*)
                            local pattern_suffix="${exclude_pattern##**/}"
                            if [[ "$file" == *"/$pattern_suffix" ]] || [[ "$(basename "$file")" == "$pattern_suffix" ]]; then
                                should_exclude=true
                                break
                            fi
                            ;;
                        # Handle **/pattern patterns (recursive pattern matching)  
                        "**/"*)
                            local pattern_part="${exclude_pattern##**/}"
                            if [[ "$file" == *"/$pattern_part" ]] || [[ "$file" == "$pattern_part" ]]; then
                                should_exclude=true
                                break
                            fi
                            ;;
                        # Handle exact file/directory patterns - only exact matches
                        *)
                            if [[ "$file" == "$exclude_pattern" ]]; then
                                should_exclude=true
                                break
                            fi
                            ;;
                    esac
                fi
            done < "$exclude_file"
            
            if [ "$should_exclude" = false ]; then
                echo "$file" >> "$final_files"
            fi
        done < "$all_files"
    else
        cp "$all_files" "$final_files"
    fi
    
    # Debug output for exclusions
    if [ -f "$CONFIG_FILE" ] && [ -s "$exclude_file" ]; then
        local total_before_exclusion=$(wc -l < "$all_files" 2>/dev/null | xargs)
        local total_after_exclusion=$(wc -l < "$final_files" 2>/dev/null | xargs)
        local excluded_count=$((total_before_exclusion - total_after_exclusion))
        echo "📊 File filtering: $total_before_exclusion found → $excluded_count excluded → $total_after_exclusion final" >&2
    fi
    
    # Return the final files
    cat "$final_files" 2>/dev/null | sort -u
    
    # Cleanup
    rm -f "$temp_file" "$exclude_file" "$all_files" "$final_files" 2>/dev/null || true
}

# Ensure temporary directory exists and is writable
if [ -z "$TMPDIR" ]; then
    export TMPDIR="/tmp"
fi

# Create temp directory if it doesn't exist
mkdir -p "$TMPDIR"

# Verify we can write to temp directory
if ! touch "$TMPDIR/test_write" 2>/dev/null; then
    echo "Warning: Cannot write to $TMPDIR, using current directory for temp files"
    export TMPDIR="$(pwd)/tmp"
    mkdir -p "$TMPDIR"
fi
rm -f "$TMPDIR/test_write" 2>/dev/null || true

echo "🔍 Starting Unity Code Analysis..."
echo ""
echo "# 🎮 Unity Code Analysis Report"
echo ""
echo "## Overview"
echo "This report provides a comprehensive analysis of your Unity C# scripts, highlighting potential issues, performance concerns, and best practice recommendations."
echo ""

ERROR_COUNT=0
WARNING_COUNT=0
INFO_COUNT=0

# File tracking variables
TOTAL_FILES_REVIEWED=0
FILES_WITH_ISSUES=()
FILES_WITHOUT_ISSUES=()

# Function to add finding to report (with severity checking)
add_finding() {
    local severity=$1
    local title=$2
    local description=$3
    local file=$4
    local line=$5
    local rule_category=$6
    local rule_name=$7
    
    # Check if rule is configured and get severity
    if [ ! -z "$rule_category" ] && [ ! -z "$rule_name" ]; then
        local configured_severity=$(get_rule_severity "$rule_category" "$rule_name")
        if [ "$configured_severity" = "disabled" ]; then
            return 0  # Skip disabled rules
        elif [ ! -z "$configured_severity" ]; then
            severity=$(echo "$configured_severity" | tr '[:lower:]' '[:upper:]')
        fi
    fi
    
    # Track file issues
    if [[ ! " ${FILES_WITH_ISSUES[@]} " =~ " ${file} " ]]; then
        FILES_WITH_ISSUES+=("$file")
    fi
    
    case $severity in
        "ERROR")
            ((ERROR_COUNT++))
            echo "## 🚨 Error: $title"
            ;;
        "WARNING")
            ((WARNING_COUNT++))
            echo "## ⚠️ Warning: $title"
            ;;
        "INFO")
            ((INFO_COUNT++))
            echo "## ℹ️ Info: $title"
            ;;
    esac
    
    echo ""
    echo "**File:** \`$file\`"
    if [ ! -z "$line" ]; then
        echo "**Line:** $line"
    fi
    echo ""
    echo "$description"
    echo ""
}

# Check for performance issues in Update methods
echo "Checking for performance issues in Update methods..."

# Check if Assets directory exists
if [ ! -d "Assets" ]; then
    echo "Warning: Assets directory not found. This might not be a Unity project root directory."
    echo "Current directory: $(pwd)"
    echo "Available directories: $(ls -la)"
    echo ""
    echo "## ⚠️ Warning: Unity Project Structure"
    echo ""
    echo "**Issue:** Assets directory not found"
    echo ""
    echo "This script should be run from the Unity project root directory that contains the Assets folder."
    echo ""
    exit 0
fi

# Check if there are any C# files to analyze
echo "📁 Discovering files to analyze based on configuration..."
FILES_TO_ANALYZE="$TMPDIR/cs_files_list.tmp"
get_files_to_analyze > "$FILES_TO_ANALYZE"

cs_file_count=$(wc -l < "$FILES_TO_ANALYZE" 2>/dev/null | xargs)
if [ "$cs_file_count" -eq 0 ]; then
    echo "## ℹ️ Info: No C# Files Found"
    echo ""
    echo "**Status:** No C# files were found matching the configured patterns"
    echo ""
    echo "**Configuration file:** $CONFIG_FILE"
    if [ -f "$CONFIG_FILE" ]; then
        echo "**Include patterns configured:**"
        parse_yaml_array "$CONFIG_FILE" "file_patterns" "include" | while read pattern; do
            echo "  - $pattern"
        done
        echo "**Exclude patterns configured:**"
        parse_yaml_array "$CONFIG_FILE" "file_patterns" "exclude" | while read pattern; do
            echo "  - $pattern"
        done
    fi
    echo ""
    echo "This is normal for projects that only use visual scripting or contain only assets."
    echo ""
    exit 0
fi

echo "Found $cs_file_count C# files to analyze..."
if [ -f "$CONFIG_FILE" ]; then
    echo "Using file patterns from: $CONFIG_FILE"
fi
echo ""
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        # Check for expensive operations in Update
        if grep -n "Update()" "$file" > /dev/null; then
            # Check for GameObject.Find in Update
            if grep -A 10 -B 2 "Update()" "$file" | grep -n "GameObject.Find\|FindObjectOfType\|FindObjectsOfType" > /dev/null; then
                add_finding "ERROR" "Expensive Find Operations in Update" \
                    "Using GameObject.Find, FindObjectOfType, or FindObjectsOfType in Update methods causes significant performance issues. Cache these references in Awake or Start instead." \
                    "$file" "$(grep -n "Update()" "$file" | cut -d: -f1)" "performance" "expensive_update_operations"
            fi
            
            # Check for Instantiate/Destroy in Update
            if grep -A 10 -B 2 "Update()" "$file" | grep -n "Instantiate\|Destroy(" > /dev/null; then
                add_finding "ERROR" "Object Creation/Destruction in Update" \
                    "Creating or destroying objects in Update methods causes performance spikes and garbage collection issues. Consider using object pooling instead." \
                    "$file" "$(grep -n "Update()" "$file" | cut -d: -f1)" "performance" "instantiate_destroy_loops"
            fi
            
            # Check for string concatenation in Update
            if grep -A 10 -B 2 "Update()" "$file" | grep -n '\+.*\".*\"' > /dev/null; then
                add_finding "WARNING" "String Concatenation in Update" \
                    "String concatenation in Update methods generates garbage. Use StringBuilder or string formatting instead." \
                    "$file" "$(grep -n "Update()" "$file" | cut -d: -f1)" "performance" "string_concatenation_loops"
            fi
        fi
    fi
done < "$FILES_TO_ANALYZE"

# Check for proper serialization practices
echo "Checking serialization practices..."
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        # Check for public fields without SerializeField
        if grep -n "public.*GameObject\|public.*Transform\|public.*Rigidbody" "$file" > /dev/null; then
            if ! grep -n "\[SerializeField\]" "$file" > /dev/null; then
                add_finding "WARNING" "Public Fields Without SerializeField" \
                    "Consider making fields private and using [SerializeField] attribute for better encapsulation." \
                    "$file" "" "unity_best_practices" "serialize_field_usage"
            fi
        fi
        
        # Check for missing null checks on Unity objects
        if grep -n "\.transform\.\|\.gameObject\.\|\.rigidbody\." "$file" > /dev/null; then
            if ! grep -n "!= null\|== null" "$file" > /dev/null; then
                add_finding "INFO" "Missing Null Checks" \
                    "Consider adding null checks for Unity object references to prevent NullReferenceExceptions." \
                    "$file" "" "unity_best_practices" "null_reference_checking"
            fi
        fi
    fi
done < "$FILES_TO_ANALYZE"

# Check for proper component caching
echo "Checking component caching patterns..."
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        # Check for repeated GetComponent calls
        getcomp_count=$(grep -c "GetComponent" "$file" 2>/dev/null || echo "0")
        getcomp_count=$(echo "$getcomp_count" | head -1)  # Take first line only
        if [ "$getcomp_count" -gt "$MAX_GETCOMPONENT_CALLS" ] 2>/dev/null; then
            add_finding "WARNING" "Repeated GetComponent Calls" \
                "Multiple GetComponent calls detected ($getcomp_count times). Cache component references in Awake or Start for better performance." \
                "$file" "" "performance" "repeated_getcomponent"
        fi
        
        # Check for proper Awake/Start usage
        if grep -n "GetComponent" "$file" > /dev/null; then
            if ! grep -n "void Awake\|void Start" "$file" > /dev/null; then
                add_finding "INFO" "Component Caching Opportunity" \
                    "Consider caching GetComponent calls in Awake or Start methods." \
                    "$file" "" "unity_best_practices" "component_caching"
            fi
        fi
    fi
done < "$FILES_TO_ANALYZE"

# Check for coroutine best practices
echo "Checking coroutine usage..."
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        if grep -n "StartCoroutine\|IEnumerator" "$file" > /dev/null; then
            # Check for proper coroutine stopping
            if grep -n "StartCoroutine" "$file" > /dev/null && ! grep -n "StopCoroutine\|StopAllCoroutines" "$file" > /dev/null; then
                add_finding "WARNING" "Missing Coroutine Cleanup" \
                    "Coroutines should be properly stopped to prevent memory leaks. Consider storing coroutine references and stopping them when needed." \
                    "$file" "" "unity_best_practices" "coroutine_lifecycle"
            fi
            
            # Check for yield return null vs WaitForEndOfFrame
            if grep -n "yield return null" "$file" > /dev/null; then
                add_finding "INFO" "Coroutine Optimization" \
                    "Consider using 'yield return WaitForEndOfFrame()' or 'yield return WaitForFixedUpdate()' instead of 'yield return null' for more explicit timing control." \
                    "$file" "" "unity_best_practices" "coroutine_optimization"
            fi
        fi
    fi
done < "$FILES_TO_ANALYZE"

# Check for Unity Events usage
echo "Checking Unity Events usage..."
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        # Check for delegate usage that could be Unity Events
        if grep -n "delegate\|event.*Action\|event.*Func" "$file" > /dev/null; then
            if ! grep -n "UnityEvent" "$file" > /dev/null; then
                add_finding "INFO" "Unity Events Suggestion" \
                    "Consider using UnityEvent instead of C# delegates for inspector-configurable events and better Unity integration." \
                    "$file" "" "unity_best_practices" "unity_events_usage"
            fi
        fi
    fi
done < "$FILES_TO_ANALYZE"

# Check for magic numbers
echo "Checking for magic numbers..."
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        # Check for magic numbers (but exclude constants and common Unity values)
        if grep -n '\b[3-9]\b\|\b[1-9][0-9]\+\b' "$file" | grep -v "0f\|1f\|2f\|-1f\|const\|readonly\|= [0-9]\+\.[0-9]*f" > /dev/null; then
            # Further filter out lines that are clearly constants or expected values
            magic_lines=$(grep -n '\b[3-9]\b\|\b[1-9][0-9]\+\b' "$file" | grep -v "0f\|1f\|2f\|-1f\|const\|readonly\|= [0-9]\+\.[0-9]*f\|DEFAULT_\|MAX_\|MIN_\|THRESHOLD")
            if [ ! -z "$magic_lines" ]; then
                add_finding "INFO" "Magic Numbers Detected" \
                    "Consider replacing magic numbers with named constants or configurable variables for better maintainability." \
                    "$file" "" "maintainability" "magic_numbers"
            fi
        fi
    fi
done < "$FILES_TO_ANALYZE"

# Check for namespace usage
echo "Checking for namespace usage..."
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        # Check if file contains classes but no namespace
        if grep -n "class\|struct\|interface\|enum" "$file" > /dev/null; then
            if ! grep -n "namespace" "$file" > /dev/null; then
                add_finding "WARNING" "Missing Namespace Declaration" \
                    "C# scripts should be wrapped in a namespace to avoid naming conflicts and improve code organization. Consider adding a namespace that reflects your project structure." \
                    "$file" "" "naming_conventions" "namespace_structure"
            fi
        fi
        
        # Check for proper namespace naming convention
        if grep -n "namespace" "$file" > /dev/null; then
            # Check if namespace follows PascalCase convention
            if grep -n "namespace [a-z]" "$file" > /dev/null; then
                add_finding "INFO" "Namespace Naming Convention" \
                    "Namespace should follow PascalCase naming convention (e.g., 'MyProject.Scripts' instead of 'myproject.scripts')." \
                    "$file" "" "naming_conventions" "namespace_naming"
            fi
        fi
    fi
done < "$FILES_TO_ANALYZE"

# Check for region usage and organization
echo "Checking for region organization..."
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        lines=$(wc -l < "$file" 2>/dev/null || echo "0")
        lines=$(echo "$lines" | head -1)  # Take first line only
        
        # For larger files (>50 lines), suggest using regions
        if [ "$lines" -gt 50 ] 2>/dev/null; then
            if ! grep -n "#region\|#endregion" "$file" > /dev/null; then
                add_finding "INFO" "Consider Using Regions" \
                    "For larger scripts ($lines lines), consider using #region blocks to organize code sections (e.g., Unity Methods, Public Methods, Private Methods, Properties, etc.)." \
                    "$file" "" "code_organization" "region_usage"
            fi
        fi
        
        # Check for unmatched regions
        region_count=$(grep -c "#region" "$file" 2>/dev/null || echo "0")
        endregion_count=$(grep -c "#endregion" "$file" 2>/dev/null || echo "0")
        region_count=$(echo "$region_count" | head -1)  # Take first line only
        endregion_count=$(echo "$endregion_count" | head -1)  # Take first line only
        
        if [ "$region_count" -ne "$endregion_count" ] 2>/dev/null; then
            add_finding "WARNING" "Unmatched Region Blocks" \
                "Found $region_count #region statements but $endregion_count #endregion statements. Ensure all regions are properly closed." \
                "$file" "" "code_organization" "region_matching"
        fi
    fi
done < "$FILES_TO_ANALYZE"

# Check for XML documentation on public methods (non-MonoBehaviour)
echo "Checking for method documentation..."
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        # Check for public methods without XML documentation
        while IFS= read -r line_num; do
            line_content=$(sed -n "${line_num}p" "$file")
            
            # Skip Unity MonoBehaviour methods (common Unity callbacks)
            if echo "$line_content" | grep -E "void (Start|Awake|Update|FixedUpdate|LateUpdate|OnEnable|OnDisable|OnDestroy|OnTrigger|OnCollision)" > /dev/null; then
                continue
            fi
            
            # Check if there's XML documentation above this method
            prev_line_num=$((line_num - 1))
            prev_line=""
            if [ $prev_line_num -gt 0 ]; then
                prev_line=$(sed -n "${prev_line_num}p" "$file" 2>/dev/null || echo "")
            fi
            
            # Look for /// summary above the method
            if ! echo "$prev_line" | grep "///" > /dev/null; then
                # Check a few lines above for summary
                found_summary=false
                for i in {1..5}; do
                    check_line_num=$((line_num - i))
                    if [ $check_line_num -gt 0 ]; then
                        check_line=$(sed -n "${check_line_num}p" "$file" 2>/dev/null || echo "")
                        if echo "$check_line" | grep "/// <summary>" > /dev/null; then
                            found_summary=true
                            break
                        fi
                    fi
                done
                
                if [ "$found_summary" = false ]; then
                    method_name=$(echo "$line_content" | grep -o "[a-zA-Z_][a-zA-Z0-9_]*(" | head -1 | sed 's/(//')
                    if [ ! -z "$method_name" ]; then
                        add_finding "INFO" "Missing Method Documentation" \
                            "Public method '$method_name' at line $line_num lacks XML documentation. Consider adding /// <summary> documentation for better code maintainability and IntelliSense support." \
                            "$file" "$line_num" "documentation" "method_documentation"
                    fi
                fi
            fi
        done < <(grep -n "public.*(" "$file" | grep -v "class\|struct\|interface" | cut -d: -f1)
    fi
done < "$FILES_TO_ANALYZE"

# Check for detailed coding conventions and naming standards
echo "Checking coding conventions and naming standards..."
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        # Check for proper variable naming conventions
        # Local variables should start with lowercase (but skip properties and interface members)
        while IFS= read -r line_num; do
            line_content=$(sed -n "${line_num}p" "$file")
            # Skip properties (lines containing { get; or { set;)
            if echo "$line_content" | grep -E "\{\s*(get|set)" > /dev/null; then
                continue
            fi
            # Skip interface members
            if echo "$line_content" | grep -E "^\s*(public|private|protected|internal)?\s*(int|float|bool|string|double)\s+[A-Z].*\s*\{\s*get" > /dev/null; then
                continue
            fi
            var_name=$(echo "$line_content" | grep -o '\(int\|float\|bool\|string\|double\) [A-Z][a-zA-Z0-9]*' | cut -d' ' -f2)
            if [ ! -z "$var_name" ]; then
                # Generate proper naming suggestion
                suggested_name="$(echo ${var_name:0:1} | tr '[:upper:]' '[:lower:]')${var_name:1}"
                add_finding "WARNING" "Local Variable Naming Convention" \
                    "Local variable '$var_name' at line $line_num should start with lowercase letter (camelCase).
**Current:** \`$(echo "$line_content" | xargs)\`
**Suggested:** \`$(echo "$line_content" | sed "s/$var_name/$suggested_name/" | xargs)\`
**Convention:** Local variables should use camelCase (e.g., playerHealth, currentSpeed, isActive)" \
                    "$file" "$line_num" "naming_conventions" "variable_naming"
            fi
        done < <(grep -n "^\s*\(int\|float\|bool\|string\|double\) [A-Z]" "$file" | grep -v -E "\{\s*(get|set)" | cut -d: -f1)
        
        # Check for member variable naming (should start with underscore)
        while IFS= read -r line_num; do
            line_content=$(sed -n "${line_num}p" "$file")
            if echo "$line_content" | grep -E "private.*\s+[a-zA-Z][a-zA-Z0-9]*\s*=" > /dev/null; then
                if ! echo "$line_content" | grep -E "private.*\s+_[a-zA-Z0-9]+" > /dev/null; then
                    # Extract the variable name more precisely
                    var_name=$(echo "$line_content" | sed -n 's/.*private.*[[:space:]]\+\([a-zA-Z][a-zA-Z0-9]*\)[[:space:]]*=.*/\1/p')
                    if [ ! -z "$var_name" ]; then
                        # Generate proper naming suggestion
                        suggested_name="_$(echo ${var_name:0:1} | tr '[:upper:]' '[:lower:]')${var_name:1}"
                        # Create the corrected line
                        suggested_line=$(echo "$line_content" | sed "s/\([[:space:]]\)$var_name\([[:space:]]*=\)/\1$suggested_name\2/")
                        add_finding "WARNING" "Private Member Variable Naming" \
                            "Private member variable '$var_name' at line $line_num should start with underscore and follow camelCase. 
**Current:** \`$(echo "$line_content" | xargs)\`
**Suggested:** \`$(echo "$suggested_line" | xargs)\`
**Convention:** Private fields should use _camelCase (e.g., _playerHealth, _moveSpeed)
**Fix:** Change '$var_name' to '$suggested_name'" \
                            "$file" "$line_num" "naming_conventions" "private_field_naming"
                    fi
                fi
            fi
        done < <(grep -n "private.*=" "$file" | cut -d: -f1)
        
        # Check for constant naming (should be ALL_CAPS)
        while IFS= read -r line_num; do
            line_content=$(sed -n "${line_num}p" "$file")
            if echo "$line_content" | grep -E "const\s+\w+\s+[a-z]" > /dev/null; then
                const_name=$(echo "$line_content" | grep -o 'const\s\+\w\+\s\+[a-zA-Z_][a-zA-Z0-9_]*' | awk '{print $3}')
                if [ ! -z "$const_name" ]; then
                    # Generate proper naming suggestion
                    suggested_name=$(echo "$const_name" | tr '[:lower:]' '[:upper:]')
                    add_finding "WARNING" "Constant Naming Convention" \
                        "Constant '$const_name' at line $line_num should be in ALL_CAPS with underscores.
**Current:** \`$line_content\`
**Suggested:** \`$(echo "$line_content" | sed "s/$const_name/$suggested_name/")\`
**Convention:** Constants should use ALL_CAPS_WITH_UNDERSCORES (e.g., MAX_HEALTH, DEFAULT_SPEED)" \
                        "$file" "$line_num" "naming_conventions" "constant_naming"
                fi
            fi
        done < <(grep -n "const.*[a-z]" "$file" | cut -d: -f1)
        
        # Check for method naming (should be PascalCase)
        while IFS= read -r line_num; do
            line_content=$(sed -n "${line_num}p" "$file")
            if echo "$line_content" | grep -E "(public|private|protected|internal).*\s+[a-z][a-zA-Z0-9]*\s*\(" > /dev/null; then
                # Skip Unity callbacks and common methods
                if ! echo "$line_content" | grep -E "(Start|Awake|Update|FixedUpdate|LateUpdate|OnEnable|OnDisable|OnDestroy|OnTrigger|OnCollision)" > /dev/null; then
                    method_name=$(echo "$line_content" | grep -o '[a-z][a-zA-Z0-9]*\s*(' | sed 's/\s*(//')
                    if [ ! -z "$method_name" ]; then
                        # Generate proper naming suggestion
                        suggested_name="$(echo ${method_name:0:1} | tr '[:lower:]' '[:upper:]')${method_name:1}"
                        add_finding "WARNING" "Method Naming Convention" \
                            "Method '$method_name' at line $line_num should start with uppercase letter (PascalCase).
**Current:** \`$(echo "$line_content" | xargs)\`
**Suggested:** \`$(echo "$line_content" | sed "s/$method_name/$suggested_name/" | xargs)\`
**Convention:** Methods should use PascalCase (e.g., GetHealth, CalculateDamage, InitializePlayer)" \
                            "$file" "$line_num" "naming_conventions" "method_naming"
                    fi
                fi
            fi
        done < <(grep -n -E "(public|private|protected|internal).*\s+[a-z][a-zA-Z0-9]*\s*\(" "$file" | cut -d: -f1)
        
        # Check for property naming (should be PascalCase)
        while IFS= read -r line_num; do
            line_content=$(sed -n "${line_num}p" "$file")
            if echo "$line_content" | grep -E "\s+[a-z][a-zA-Z0-9]*\s*\{\s*(get|set)" > /dev/null; then
                prop_name=$(echo "$line_content" | grep -o '[a-z][a-zA-Z0-9]*\s*{' | sed 's/\s*{//')
                if [ ! -z "$prop_name" ]; then
                    # Generate proper naming suggestion
                    suggested_name="$(echo ${prop_name:0:1} | tr '[:lower:]' '[:upper:]')${prop_name:1}"
                    add_finding "WARNING" "Property Naming Convention" \
                        "Property '$prop_name' at line $line_num should start with uppercase letter (PascalCase).
**Current:** \`$(echo "$line_content" | xargs)\`
**Suggested:** \`$(echo "$line_content" | sed "s/$prop_name/$suggested_name/" | xargs)\`
**Convention:** Properties should use PascalCase (e.g., Health, IsAlive, MaxSpeed)" \
                        "$file" "$line_num" "naming_conventions" "property_naming"
                fi
            fi
        done < <(grep -n -E "\s+[a-z][a-zA-Z0-9]*\s*\{\s*(get|set)" "$file" | cut -d: -f1)
        
        # Check for interface naming (should start with 'I')
        while IFS= read -r line_num; do
            line_content=$(sed -n "${line_num}p" "$file")
            if echo "$line_content" | grep -E "interface\s+[A-Z][a-zA-Z0-9]*" > /dev/null; then
                if ! echo "$line_content" | grep -E "interface\s+I[A-Z]" > /dev/null; then
                    interface_name=$(echo "$line_content" | grep -o 'interface\s\+[A-Z][a-zA-Z0-9]*' | awk '{print $2}')
                    if [ ! -z "$interface_name" ]; then
                        # Generate proper naming suggestion
                        suggested_name="I$interface_name"
                        add_finding "ERROR" "Interface Naming Convention" \
                            "Interface '$interface_name' at line $line_num must start with 'I' prefix.
**Current:** \`$(echo "$line_content" | xargs)\`
**Suggested:** \`$(echo "$line_content" | sed "s/interface $interface_name/interface $suggested_name/" | xargs)\`
**Convention:** Interfaces must use IPascalCase (e.g., IWeapon, IHealthSystem, IMoveable)
**Why:** This clearly identifies interfaces and follows Microsoft C# guidelines." \
                            "$file" "$line_num" "naming_conventions" "interface_naming"
                    fi
                fi
            fi
        done < <(grep -n "interface" "$file" | cut -d: -f1)
        
        # Check for class naming (should be PascalCase) - but skip comments
        while IFS= read -r line_num; do
            line_content=$(sed -n "${line_num}p" "$file")
            # Skip comment lines
            if echo "$line_content" | grep -E "^\s*///" > /dev/null; then
                continue
            fi
            if echo "$line_content" | grep -E "class\s+[a-z]" > /dev/null; then
                class_name=$(echo "$line_content" | grep -o 'class\s\+[a-z][a-zA-Z0-9]*' | awk '{print $2}')
                if [ ! -z "$class_name" ]; then
                    # Generate proper naming suggestion
                    suggested_name="$(echo ${class_name:0:1} | tr '[:lower:]' '[:upper:]')${class_name:1}"
                    add_finding "WARNING" "Class Naming Convention" \
                        "Class '$class_name' at line $line_num should start with uppercase letter (PascalCase).
**Current:** \`$(echo "$line_content" | xargs)\`
**Suggested:** \`$(echo "$line_content" | sed "s/class $class_name/class $suggested_name/" | xargs)\`
**Convention:** Classes should use PascalCase (e.g., PlayerController, HealthSystem, WeaponManager)" \
                        "$file" "$line_num" "naming_conventions" "class_naming"
                fi
            fi
        done < <(grep -n "class.*[a-z]" "$file" | grep -v "^\s*///" | cut -d: -f1)
        
        # Check for SerializeField usage with proper access modifiers
        while IFS= read -r line_num; do
            line_content=$(sed -n "${line_num}p" "$file")
            next_line_num=$((line_num + 1))
            next_line=$(sed -n "${next_line_num}p" "$file" 2>/dev/null || echo "")
            
            if echo "$line_content" | grep "\[SerializeField\]" > /dev/null; then
                if echo "$next_line" | grep "public" > /dev/null; then
                    add_finding "WARNING" "SerializeField Access Modifier" \
                        "SerializeField at line $line_num should be used with private fields, not public. Make the field private for better encapsulation." \
                        "$file" "$line_num" "unity_best_practices" "serialize_field_access"
                fi
            fi
        done < <(grep -n "\[SerializeField\]" "$file" | cut -d: -f1)
        
        # Check for proper access modifier usage
        if grep -n "public.*=" "$file" > /dev/null; then
            add_finding "INFO" "Access Modifier Usage" \
                "Consider using appropriate access modifiers: public for button callbacks, internal for cross-script module access, protected for inheritance, private for same script access." \
                "$file" "" "code_organization" "access_modifiers"
        fi
        
        # Check for Unity-specific naming patterns
        # Check for event naming (should start with 'On')
        while IFS= read -r line_num; do
            line_content=$(sed -n "${line_num}p" "$file")
            if echo "$line_content" | grep -E "(Action|UnityEvent).*[a-z]" > /dev/null; then
                event_name=$(echo "$line_content" | grep -o '[a-z][a-zA-Z0-9]*.*=' | sed 's/\s*=.*//')
                if [ ! -z "$event_name" ] && [[ ! "$event_name" =~ ^On ]]; then
                    suggested_name="On$(echo ${event_name:0:1} | tr '[:lower:]' '[:upper:]')${event_name:1}"
                    add_finding "WARNING" "Event Naming Convention" \
                        "Event '$event_name' at line $line_num should start with 'On' prefix.
**Current:** \`$(echo "$line_content" | xargs)\`
**Suggested:** \`$(echo "$line_content" | sed "s/$event_name/$suggested_name/" | xargs)\`
**Convention:** Events should use OnPascalCase (e.g., OnPlayerDeath, OnHealthChanged, OnLevelComplete)" \
                        "$file" "$line_num" "naming_conventions" "event_naming"
                fi
            fi
        done < <(grep -n -E "(Action|UnityEvent)" "$file" | cut -d: -f1)
        
        # Check for method parameter naming
        while IFS= read -r line_num; do
            line_content=$(sed -n "${line_num}p" "$file")
            if echo "$line_content" | grep -E "\([^)]*[A-Z][a-zA-Z0-9]*\s+[A-Z]" > /dev/null; then
                # Extract parameters with wrong naming
                params=$(echo "$line_content" | grep -o '([^)]*)' | sed 's/[()]//g')
                if [ ! -z "$params" ]; then
                    # Check each parameter
                    IFS=',' read -ra PARAM_ARRAY <<< "$params"
                    for param in "${PARAM_ARRAY[@]}"; do
                        if echo "$param" | grep -E "[A-Z][a-zA-Z0-9]*\s+[A-Z]" > /dev/null; then
                            param_name=$(echo "$param" | grep -o '[A-Z][a-zA-Z0-9]*$' | tail -1)
                            if [ ! -z "$param_name" ]; then
                                suggested_name="$(echo ${param_name:0:1} | tr '[:upper:]' '[:lower:]')${param_name:1}"
                                add_finding "WARNING" "Parameter Naming Convention" \
                                    "Parameter '$param_name' at line $line_num should use camelCase.
**Current parameter:** \`$param\`
**Suggested:** \`$(echo "$param" | sed "s/$param_name/$suggested_name/")\`
**Convention:** Method parameters should use camelCase (e.g., playerHealth, targetPosition)" \
                                    "$file" "$line_num" "naming_conventions" "parameter_naming"
                            fi
                        fi
                    done
                fi
            fi
        done < <(grep -n -E "\([^)]*[A-Z][a-zA-Z0-9]*\s+[A-Z]" "$file" | cut -d: -f1)
        
        # Check for single letter variable names (bad practice)
        while IFS= read -r line_num; do
            line_content=$(sed -n "${line_num}p" "$file")
            if echo "$line_content" | grep -E "\s+[a-zA-Z]\s*=" > /dev/null; then
                var_name=$(echo "$line_content" | grep -o '\s[a-zA-Z]\s*=' | sed 's/\s*=.*//' | sed 's/^\s*//')
                if [[ ${#var_name} -eq 1 ]]; then
                    # Generate meaningful naming suggestions based on context
                    context_type=$(echo "$line_content" | grep -o '\(int\|float\|bool\|string\|Vector3\|Transform\|GameObject\)')
                    case $context_type in
                        "int")
                            suggestions="count, index, health, damage, score"
                            ;;
                        "float")
                            suggestions="speed, time, distance, angle, scale"
                            ;;
                        "bool")
                            suggestions="isActive, canMove, hasWeapon, isDead"
                            ;;
                        "string")
                            suggestions="playerName, message, tag, sceneName"
                            ;;
                        "Vector3")
                            suggestions="position, velocity, direction, offset"
                            ;;
                        "Transform")
                            suggestions="playerTransform, targetTransform, spawnPoint"
                            ;;
                        "GameObject")
                            suggestions="player, enemy, target, weapon"
                            ;;
                        *)
                            suggestions="meaningfulName, descriptiveName"
                            ;;
                    esac
                    add_finding "ERROR" "Meaningful Variable Names" \
                        "Single letter variable '$var_name' at line $line_num is not descriptive.
**Current:** \`$(echo "$line_content" | xargs)\`
**Suggested names for $context_type:** $suggestions
**Convention:** Use descriptive names that clearly indicate the variable's purpose
**Example:** Instead of 'int x = 100;' use 'int maxHealth = 100;'" \
                        "$file" "$line_num" "naming_conventions" "meaningful_names"
                fi
            fi
        done < <(grep -n -E "\s+[a-zA-Z]\s*=" "$file" | cut -d: -f1)
    fi
done < "$FILES_TO_ANALYZE"

# Check for namespace structure and organization
echo "Checking namespace structure and organization..."
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        # Check for nested namespace structure
        if grep -n "namespace" "$file" > /dev/null; then
            namespace_line=$(grep "namespace" "$file" | head -1)
            namespace_name=$(echo "$namespace_line" | grep -o 'namespace\s\+[a-zA-Z0-9.]*' | awk '{print $2}')
            
            # Check if namespace follows proper structure (ParentName.ModuleName)
            if [[ "$namespace_name" != *.* ]]; then
                add_finding "INFO" "Namespace Structure" \
                    "Consider using nested namespace structure like 'ProjectName.ModuleName' (e.g., 'PB.Player', 'PB.UI'). Current namespace: '$namespace_name'" \
                    "$file" "" "code_organization" "namespace_structure"
            fi
            
            # Check if namespace reflects folder structure
            folder_path=$(dirname "$file" | sed 's|Assets/Scripts||' | sed 's|/|.|g' | sed 's/^\.*//')
            if [ ! -z "$folder_path" ]; then
                if ! echo "$namespace_name" | grep -i "$folder_path" > /dev/null; then
                    add_finding "INFO" "Namespace Folder Alignment" \
                        "Namespace '$namespace_name' should reflect folder structure. Consider aligning with folder path: '$folder_path'" \
                        "$file" "" "code_organization" "namespace_alignment"
                fi
            fi
        fi
    fi
done < "$FILES_TO_ANALYZE"

# Check for design patterns and architecture
echo "Checking for design patterns and architecture..."
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        # Check for interface usage and polymorphism
        if grep -n "class.*:" "$file" > /dev/null; then
            if ! grep -n "interface\|abstract" "$file" > /dev/null; then
                add_finding "INFO" "Design Patterns - Interface Usage" \
                    "Consider implementing interfaces for better decoupling and polymorphism. This improves scalability and testability." \
                    "$file" "" "code_organization" "interface_usage"
            fi
        fi
        
        # Check for delegate and event usage
        if grep -n "Action\|Func" "$file" > /dev/null; then
            if ! grep -n "event\|delegate" "$file" > /dev/null; then
                add_finding "INFO" "Design Patterns - Events" \
                    "Consider using events and delegates for decoupling. This helps achieve better architecture and reduces dependencies." \
                    "$file" "" "code_organization" "event_usage"
            fi
        fi
        
        # Check for singleton pattern (often overused)
        if grep -n -i "singleton\|instance.*static" "$file" > /dev/null; then
            add_finding "WARNING" "Design Pattern - Singleton Usage" \
                "Singleton pattern detected. Ensure this is necessary as it can make testing difficult and create tight coupling." \
                "$file" "" "design_patterns" "singleton_usage"
        fi
        
        # Check for proper use of MonoBehaviour inheritance
        if grep -n "class.*MonoBehaviour" "$file" > /dev/null; then
            if ! grep -n "void.*Update\|void.*Start\|void.*Awake" "$file" > /dev/null; then
                add_finding "INFO" "MonoBehaviour Usage" \
                    "Class inherits from MonoBehaviour but doesn't use Unity lifecycle methods. Consider using regular C# class if Unity features aren't needed." \
                    "$file" "" "unity_best_practices" "monobehaviour_usage"
            fi
        fi
    fi
done < "$FILES_TO_ANALYZE"

# Calculate file statistics
echo "Calculating file statistics..."
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        ((TOTAL_FILES_REVIEWED++))
        # Check if this file has issues
        if [[ ! " ${FILES_WITH_ISSUES[@]} " =~ " ${file} " ]]; then
            FILES_WITHOUT_ISSUES+=("$file")
        fi
    fi
done < "$FILES_TO_ANALYZE"

FILES_WITH_ISSUES_COUNT=${#FILES_WITH_ISSUES[@]}
FILES_WITHOUT_ISSUES_COUNT=${#FILES_WITHOUT_ISSUES[@]}

# Add summary to report
echo ""
echo "---"
echo ""
echo "## 📊 Analysis Summary"
echo ""
echo "### ⚙️ Configuration"
if [ -f "$CONFIG_FILE" ]; then
    echo "- **Configuration file:** \`$CONFIG_FILE\`"
    echo "- **Namespace prefix:** $NAMESPACE_PREFIX"
    echo "- **Max GetComponent calls threshold:** $MAX_GETCOMPONENT_CALLS"
    echo "- **Suggest regions threshold:** $SUGGEST_REGIONS_LINES lines"
    echo "- **File size threshold:** $FILE_SIZE_LINES lines"
else
    echo "- **Configuration:** Using default settings (config file not found)"
fi
echo ""
echo "### 📁 File Statistics"
echo "- **Total Files Reviewed:** $TOTAL_FILES_REVIEWED"
if [ $TOTAL_FILES_REVIEWED -gt 0 ]; then
    echo "- **Files Following Conventions:** $FILES_WITHOUT_ISSUES_COUNT ($(( FILES_WITHOUT_ISSUES_COUNT * 100 / TOTAL_FILES_REVIEWED ))%)"
    echo "- **Files with Issues:** $FILES_WITH_ISSUES_COUNT ($(( FILES_WITH_ISSUES_COUNT * 100 / TOTAL_FILES_REVIEWED ))%)"
else
    echo "- **Files Following Conventions:** 0 (0%)"
    echo "- **Files with Issues:** 0 (0%)"
fi
echo ""
echo "### 🔍 Issue Statistics"
echo "- **Errors:** $ERROR_COUNT"
echo "- **Warnings:** $WARNING_COUNT"
echo "- **Info/Suggestions:** $INFO_COUNT"
echo "- **Total Issues:** $(( ERROR_COUNT + WARNING_COUNT + INFO_COUNT ))"
echo ""

if [ $FILES_WITHOUT_ISSUES_COUNT -gt 0 ]; then
    echo "### ✅ Files Following All Conventions:"
    echo ""
    for file in "${FILES_WITHOUT_ISSUES[@]}"; do
        echo "- \`$file\` ✅"
    done
    echo ""
fi

if [ $FILES_WITH_ISSUES_COUNT -gt 0 ]; then
    echo "### ⚠️ Files Needing Attention:"
    echo ""
    for file in "${FILES_WITH_ISSUES[@]}"; do
        echo "- \`$file\`"
    done
    echo ""
fi

echo "✅ Unity Code Analysis Complete!"
echo "📊 Found: $ERROR_COUNT errors, $WARNING_COUNT warnings, $INFO_COUNT suggestions"
echo "📁 Reviewed: $TOTAL_FILES_REVIEWED files ($FILES_WITHOUT_ISSUES_COUNT clean, $FILES_WITH_ISSUES_COUNT with issues)"

# Cleanup temporary files
rm -f "$FILES_TO_ANALYZE" 2>/dev/null || true

# Set exit code based on errors
if [ $ERROR_COUNT -gt 0 ]; then
    echo "❌ Analysis completed with errors"
    exit 1
else
    echo "✅ Analysis completed successfully"
    exit 0
fi
