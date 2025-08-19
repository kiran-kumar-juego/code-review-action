#!/bin/bash

# Beautiful Unity Code Analyzer with formatted output
# This script performs detailed analysis of Unity C# scripts for common issues and best practices

# Disable exit on error for analysis sections to prevent early termination
set +e

# Add debugging trap - commented out for now
# trap 'echo "❌ Script failed at line $LINENO with command: $BASH_COMMAND" >&2' ERR

# Configuration defaults
NAMESPACE_PREFIX="MyProject"
MAX_GETCOMPONENT_CALLS=3
SUGGEST_REGIONS_LINES=50
FILE_SIZE_LINES=100

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration file path (relative to script location)
CONFIG_FILE="$SCRIPT_DIR/../unity-review-config.yml"

# Function to extract config values
extract_config_value() {
    local key="$1"
    local default_value="$2"
    local config_file="$3"
    
    if [ -f "$config_file" ]; then
        local value=$(grep -E "^\s*${key}:" "$config_file" | head -1 | sed 's/.*:\s*//' | tr -d '"' || echo "$default_value")
        echo "${value:-$default_value}"
    else
        echo "$default_value"
    fi
}

# Helper function to safely count grep results
safe_grep_count() {
    local pattern="$1"
    local file="$2"
    local count=$(grep -c "$pattern" "$file" 2>/dev/null | head -1)
    if [[ "$count" =~ ^[0-9]+$ ]]; then
        echo "$count"
    else
        echo "0"
    fi
}

# Function to extract naming convention patterns
extract_naming_pattern() {
    local pattern_type="$1"
    local config_file="$2"
    
    if [ ! -f "$config_file" ]; then
        return 1
    fi
    
    # Extract pattern from YAML config
    awk "
    /^naming_enforcement:/ { in_enforcement = 1; next }
    /^[a-zA-Z]/ && in_enforcement { in_enforcement = 0 }
    /^  ${pattern_type}:/ && in_enforcement { in_section = 1; next }
    /^  [a-zA-Z]/ && in_enforcement && in_section { in_section = 0 }
    /^    detect_pattern:/ && in_section { 
        gsub(/^    detect_pattern: \"/, \"\"); 
        gsub(/\"$/, \"\"); 
        print 
    }
    " "$config_file"
}

# Load configuration values from YAML if available
if [ -f "$CONFIG_FILE" ]; then
    echo "📋 Loading configuration from: $CONFIG_FILE" >&2
    NAMESPACE_PREFIX=$(extract_config_value "namespace_prefix" "$NAMESPACE_PREFIX" "$CONFIG_FILE")
    FILE_SIZE_LINES=$(extract_config_value "file_size_lines" "$FILE_SIZE_LINES" "$CONFIG_FILE")
    SUGGEST_REGIONS_LINES=$(extract_config_value "suggest_regions_lines" "$SUGGEST_REGIONS_LINES" "$CONFIG_FILE")
    MAX_GETCOMPONENT_CALLS=$(extract_config_value "max_getcomponent_calls" "$MAX_GETCOMPONENT_CALLS" "$CONFIG_FILE")
    
    # Load performance monitoring thresholds
    ALLOCATION_THRESHOLD=$(extract_config_value "allocation_threshold" "50" "$CONFIG_FILE")
    GC_PRESSURE_THRESHOLD=$(extract_config_value "gc_pressure_threshold" "20" "$CONFIG_FILE")
    METHOD_COMPLEXITY=$(extract_config_value "method_complexity" "15" "$CONFIG_FILE")
    
    echo "🔧 Configuration loaded successfully" >&2
else
    echo "⚠️ Configuration file not found, using defaults" >&2
    ALLOCATION_THRESHOLD=50
    GC_PRESSURE_THRESHOLD=20
    METHOD_COMPLEXITY=15
fi

# Function to extract patterns from YAML config
extract_patterns() {
    local pattern_type="$1"  # "include" or "exclude"
    local config_file="$2"
    
    if [ ! -f "$config_file" ]; then
        echo "⚠️ Config file not found: $config_file" >&2
        return 1
    fi
    
    # Extract patterns using sed/awk (simple YAML parsing)
    awk "
    /^file_patterns:/ { in_file_patterns = 1; next }
    /^[a-zA-Z]/ && in_file_patterns { in_file_patterns = 0 }
    /^  ${pattern_type}:/ && in_file_patterns { in_section = 1; next }
    /^  [a-zA-Z]/ && in_file_patterns && in_section { in_section = 0 }
    /^    - \".*\"/ && in_section { 
        gsub(/^    - \"/, \"\"); 
        gsub(/\"$/, \"\"); 
        print 
    }
    " "$config_file"
}

# Function to check if a file matches any pattern
matches_pattern() {
    local file="$1"
    local pattern="$2"
    
    # Use bash pattern matching with globbing enabled
    shopt -s extglob
    case "$file" in
        $pattern) return 0 ;;
        *) return 1 ;;
    esac
}

# Function to filter files based on include/exclude patterns
filter_files_by_config() {
    local input_file="$1"
    local output_file="$2"
    local config_file="$3"
    
    # Clear output file
    > "$output_file"
    
    if [ ! -f "$config_file" ]; then
        echo "⚠️ Config file not found, using all files" >&2
        cp "$input_file" "$output_file"
        return
    fi
    
    # Extract include and exclude patterns
    local include_patterns=$(extract_patterns "include" "$config_file")
    local exclude_patterns=$(extract_patterns "exclude" "$config_file")
    
    echo "🔧 Applying file filters from config..." >&2
    
    # Process each file
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        
        # Check if file matches any include pattern (default to include if no patterns)
        local included=false
        if [ -z "$include_patterns" ]; then
            included=true
        else
            while IFS= read -r pattern; do
                [ -z "$pattern" ] && continue
                if matches_pattern "$file" "$pattern"; then
                    included=true
                    break
                fi
            done <<< "$include_patterns"
        fi
        
        # Check if file matches any exclude pattern
        local excluded=false
        if [ -n "$exclude_patterns" ]; then
            while IFS= read -r pattern; do
                [ -z "$pattern" ] && continue
                if matches_pattern "$file" "$pattern"; then
                    excluded=true
                    break
                fi
            done <<< "$exclude_patterns"
        fi
        
        # Include file if it matches include patterns and doesn't match exclude patterns
        if [ "$included" = true ] && [ "$excluded" = false ]; then
            echo "$file" >> "$output_file"
        fi
    done < "$input_file"
    
    local filtered_count=$(wc -l < "$output_file")
    local original_count=$(wc -l < "$input_file")
    echo "✅ Filtered: $original_count → $filtered_count files" >&2
}

# Files to analyze (create from environment or all .cs files in Assets)
FILES_TO_ANALYZE=$(mktemp)
FILES_FILTERED=$(mktemp)

# Determine which files to analyze
if [ "$ANALYZE_ALL_FILES" = "true" ]; then
    find Assets -name "*.cs" -type f > "$FILES_TO_ANALYZE" 2>/dev/null || true
elif [ -n "$CHANGED_FILES" ]; then
    echo "$CHANGED_FILES" | tr ' ' '\n' | grep '\.cs$' | grep '^Assets/' > "$FILES_TO_ANALYZE" 2>/dev/null || true
else
    find Assets -name "*.cs" -type f > "$FILES_TO_ANALYZE" 2>/dev/null || true
fi

# Apply include/exclude filters from config
filter_files_by_config "$FILES_TO_ANALYZE" "$FILES_FILTERED" "$CONFIG_FILE"

# Use filtered file list
mv "$FILES_FILTERED" "$FILES_TO_ANALYZE"

# Check if we have files to analyze
if [ ! -s "$FILES_TO_ANALYZE" ]; then
    # Create minimal report
    REPORT_FILE="${GITHUB_WORKSPACE:-$(pwd)}/unity-analysis-report.md"
    {
        echo "# 🎮 Unity Code Analysis Report"
        echo ""
        echo "**Analysis Type:** No Files Found"
        echo "**Analysis Date:** $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        echo "## 📊 Summary:"
        echo ""
        echo "- **Files Analyzed:** 0 (No C# files found in Assets folder)"
        echo ""
        echo "### ✅ **No issues found** 🎉"
        echo ""
        echo "> 💚 No Unity C# files were found to analyze in the Assets folder."
        echo ""
        echo "---"
        echo ""
        echo "*Report generated by Unity Code Analyzer on $(date '+%Y-%m-%d %H:%M:%S')*"
    } > "$REPORT_FILE"
    
    rm -f "$FILES_TO_ANALYZE" 2>/dev/null || true
    exit 0
fi

# Always create the analysis report file for artifact upload in the workspace root
REPORT_FILE="${GITHUB_WORKSPACE:-$(pwd)}/unity-analysis-report.md"

# Initialize issue counters
CRITICAL_ISSUES=0
WARNING_ISSUES=0
INFO_ISSUES=0

# Initialize performance monitoring variables
allocation_indicators=0
gc_pressure_indicators=0
total_methods=0
complex_methods=0
total_cyclomatic_complexity=0
interface_implementations=0
total_classes=0

# Create a comprehensive, beautifully formatted report
{
echo "# 🎮 Unity Code Analysis Report"
echo ""
echo "**Analysis Type:** Comprehensive Unity C# Analysis"
echo "**Trigger:** Automated Code Review"
echo "**Analysis Date:** $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo "## 📊 Summary:"
echo ""
file_count=$(wc -l < "$FILES_TO_ANALYZE" 2>/dev/null || echo "0")
echo "- **Files Analyzed:** $file_count"
echo ""

# Critical Issues Section
echo "### 🚨 **ERRORS (CRITICAL ISSUES)** 🚨"
echo ""

# Check for expensive operations in Update methods
find_in_update_results=""
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        if grep -n "Update()" "$file" > /dev/null 2>&1; then
            if grep -A 10 -B 2 "Update()" "$file" | grep -q "GameObject\.Find\|FindObjectOfType\|FindObjectsOfType" 2>/dev/null; then
                update_line=$(grep -n "Update()" "$file" 2>/dev/null | head -1 | cut -d: -f1)
                find_in_update_results="${find_in_update_results}$(basename "$file"):$update_line:Find operation in Update\n"
                CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
            fi
        fi
    fi
done < "$FILES_TO_ANALYZE"

if [ -n "$find_in_update_results" ]; then
    echo "#### 🔥 **Find operations in Update methods**"
    echo ""
    echo "| File | Line | Issue |"
    echo "|------|------|-------|"
    echo -e "$find_in_update_results" | while IFS= read -r line; do
        if [[ $line == *":"* ]]; then
            file=$(echo "$line" | cut -d: -f1)
            line_num=$(echo "$line" | cut -d: -f2)
            echo "| \`$file\` | **$line_num** | Expensive Find operation detected |"
        fi
    done
    echo ""
    echo "> ⚠️ **Impact:** Significant performance issue - cache these references in Awake/Start"
    echo ""
fi

# Check for Instantiate/Destroy in Update
instantiate_destroy_results=""
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        if grep -n "Update()" "$file" > /dev/null 2>&1; then
            if grep -A 10 -B 2 "Update()" "$file" | grep -q "Instantiate\|Destroy" 2>/dev/null; then
                update_line=$(grep -n "Update()" "$file" 2>/dev/null | head -1 | cut -d: -f1)
                instantiate_destroy_results="${instantiate_destroy_results}$(basename "$file"):$update_line:Object creation/destruction in Update\n"
                CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
            fi
        fi
    fi
done < "$FILES_TO_ANALYZE"

if [ -n "$instantiate_destroy_results" ]; then
    echo "#### 💥 **Instantiate/Destroy in Update methods**"
    echo ""
    echo "| File | Line | Issue |"
    echo "|------|------|-------|"
    echo -e "$instantiate_destroy_results" | while IFS= read -r line; do
        if [[ $line == *":"* ]]; then
            file=$(echo "$line" | cut -d: -f1)
            line_num=$(echo "$line" | cut -d: -f2)
            echo "| \`$file\` | **$line_num** | Object instantiation/destruction in Update |"
        fi
    done
    echo ""
    echo "> ⚠️ **Impact:** Major performance concern - these operations are expensive in Update loops"
    echo ""
fi

# Check for GetComponent without null checking
getcomponent_results=""
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        getcomp_lines=$(grep -n "\.GetComponent<.*>()" "$file" 2>/dev/null | grep -v "null" | head -5)
        if [ -n "$getcomp_lines" ]; then
            while IFS= read -r getcomp_line; do
                if [[ $getcomp_line == *":"* ]]; then
                    getcomponent_results="${getcomponent_results}$file:$getcomp_line\n"
                fi
            done <<< "$getcomp_lines"
            CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
        fi
    fi
done < "$FILES_TO_ANALYZE"

if [ -n "$getcomponent_results" ]; then
    echo "#### 💥 **GetComponent calls without null checking**"
    echo ""
    echo "| File | Line | Code |"
    echo "|------|------|------|"
    echo -e "$getcomponent_results" | while IFS= read -r line; do
        if [[ $line == *":"* ]]; then
            file=$(echo "$line" | cut -d: -f1)
            line_num=$(echo "$line" | cut -d: -f2)
            code=$(echo "$line" | cut -d: -f3- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            echo "| \`$(basename "$file")\` | **$line_num** | \`$code\` |"
        fi
    done
    echo ""
    echo "> ⚠️ **Risk:** Potential null reference exceptions"
    echo ""
fi

# Check for string concatenation in Update loops
string_concat_update_results=""
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        if grep -n "Update()" "$file" > /dev/null 2>&1; then
            if grep -A 10 -B 2 "Update()" "$file" | grep -q ".*+.*\".*\"" 2>/dev/null; then
                update_line=$(grep -n "Update()" "$file" 2>/dev/null | head -1 | cut -d: -f1)
                string_concat_update_results="${string_concat_update_results}$(basename "$file"):$update_line:String concatenation in Update\n"
                CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
            fi
        fi
    fi
done < "$FILES_TO_ANALYZE"

if [ -n "$string_concat_update_results" ]; then
    echo "#### 🔗 **String concatenation in Update methods**"
    echo ""
    echo "| File | Line | Issue |"
    echo "|------|------|-------|"
    echo -e "$string_concat_update_results" | while IFS= read -r line; do
        if [[ $line == *":"* ]]; then
            file=$(echo "$line" | cut -d: -f1)
            line_num=$(echo "$line" | cut -d: -f2)
            echo "| \`$file\` | **$line_num** | String concatenation generates garbage |"
        fi
    done
    echo ""
    echo "> ⚠️ **Impact:** Memory allocation and garbage collection pressure"
    echo ""
fi

# Check for Camera.main usage in Update loops
camera_main_update_results=""
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        if grep -n "Update()" "$file" > /dev/null 2>&1; then
            if grep -A 10 -B 2 "Update()" "$file" | grep -q "Camera\.main" 2>/dev/null; then
                update_line=$(grep -n "Update()" "$file" 2>/dev/null | head -1 | cut -d: -f1)
                camera_main_update_results="${camera_main_update_results}$(basename "$file"):$update_line:Camera.main in Update\n"
                CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
            fi
        fi
    fi
done < "$FILES_TO_ANALYZE"

if [ -n "$camera_main_update_results" ]; then
    echo "#### 📷 **Camera.main in Update loops**"
    echo ""
    echo "| File | Line | Issue |"
    echo "|------|------|-------|"
    echo -e "$camera_main_update_results" | while IFS= read -r line; do
        if [[ $line == *":"* ]]; then
            file=$(echo "$line" | cut -d: -f1)
            line_num=$(echo "$line" | cut -d: -f2)
            echo "| \`$file\` | **$line_num** | Camera.main uses expensive FindObjectWithTag |"
        fi
    done
    echo ""
    echo "> ⚠️ **Impact:** Camera.main calls FindObjectWithTag internally - cache the reference"
    echo ""
fi

# Check for naming convention violations
naming_violations_results=""
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        # Check for private/protected fields without underscore prefix
        private_field_lines=$(grep -n "private.*[^_][a-zA-Z][a-zA-Z0-9]*;" "$file" 2>/dev/null | grep -v "_" | head -5)
        if [ -n "$private_field_lines" ]; then
            while IFS= read -r field_line; do
                if [[ $field_line == *":"* ]]; then
                    naming_violations_results="${naming_violations_results}$file:$field_line:Private field should start with underscore (_)\n"
                fi
            done <<< "$private_field_lines"
            CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
        fi
        
        protected_field_lines=$(grep -n "protected.*[^_][a-zA-Z][a-zA-Z0-9]*;" "$file" 2>/dev/null | grep -v "_" | head -5)
        if [ -n "$protected_field_lines" ]; then
            while IFS= read -r field_line; do
                if [[ $field_line == *":"* ]]; then
                    naming_violations_results="${naming_violations_results}$file:$field_line:Protected field should start with underscore (_)\n"
                fi
            done <<< "$protected_field_lines"
            CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
        fi
        
        # Check for constants not in ALL_CAPS
        const_lines=$(grep -n "const.*[a-z].*=" "$file" 2>/dev/null | head -3)
        if [ -n "$const_lines" ]; then
            while IFS= read -r const_line; do
                if [[ $const_line == *":"* ]]; then
                    naming_violations_results="${naming_violations_results}$file:$const_line:Constant should be ALL_CAPS\n"
                fi
            done <<< "$const_lines"
            CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
        fi
        
        # Check for local variables starting with capital letter (inside methods)
        local_var_lines=$(grep -A 20 -B 2 "^\s*{" "$file" 2>/dev/null | grep -E "^\s*int\s+[A-Z]|^\s*float\s+[A-Z]|^\s*string\s+[A-Z]|^\s*bool\s+[A-Z]" | head -3)
        if [ -n "$local_var_lines" ]; then
            while IFS= read -r var_line; do
                if [[ $var_line == *":"* ]]; then
                    naming_violations_results="${naming_violations_results}$file:$var_line:Local variable should use camelCase\n"
                fi
            done <<< "$local_var_lines"
            CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
        fi
        
        # Check for public fields not in PascalCase (should be properties)
        public_field_lines=$(grep -n "public.*[a-z][a-zA-Z0-9]*;" "$file" 2>/dev/null | grep -v "const\|readonly" | head -3)
        if [ -n "$public_field_lines" ]; then
            while IFS= read -r field_line; do
                if [[ $field_line == *":"* ]]; then
                    naming_violations_results="${naming_violations_results}$file:$field_line:Public field should use PascalCase or be a property\n"
                fi
            done <<< "$public_field_lines"
            CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
        fi
        
        # Check for non-PascalCase methods
        method_lines=$(grep -n "public.*[a-z][a-zA-Z0-9]*(" "$file" 2>/dev/null | grep -v "^[[:space:]]*//\|^[[:space:]]*\*" | head -3)
        if [ -n "$method_lines" ]; then
            while IFS= read -r method_line; do
                if [[ $method_line == *":"* ]]; then
                    naming_violations_results="${naming_violations_results}$file:$method_line:Method should use PascalCase\n"
                fi
            done <<< "$method_lines"
            CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
        fi
        
        # Check for non-PascalCase classes
        class_lines=$(grep -n "class [a-z][a-zA-Z0-9]*" "$file" 2>/dev/null | head -3)
        if [ -n "$class_lines" ]; then
            while IFS= read -r class_line; do
                if [[ $class_line == *":"* ]]; then
                    naming_violations_results="${naming_violations_results}$file:$class_line:Class should use PascalCase (start with capital letter)\n"
                fi
            done <<< "$class_lines"
            CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
        fi
        
        # Check for classes with underscores
        underscore_class_lines=$(grep -n "class.*_" "$file" 2>/dev/null | head -3)
        if [ -n "$underscore_class_lines" ]; then
            while IFS= read -r class_line; do
                if [[ $class_line == *":"* ]]; then
                    naming_violations_results="${naming_violations_results}$file:$class_line:Class should not contain underscores (use PascalCase)\n"
                fi
            done <<< "$underscore_class_lines"
            CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
        fi
        
        # Check for all-caps classes
        allcaps_class_lines=$(grep -n "class [A-Z][A-Z_]*[A-Z]" "$file" 2>/dev/null | head -3)
        if [ -n "$allcaps_class_lines" ]; then
            while IFS= read -r class_line; do
                if [[ $class_line == *":"* ]]; then
                    naming_violations_results="${naming_violations_results}$file:$class_line:Class should use PascalCase, not ALL_CAPS\n"
                fi
            done <<< "$allcaps_class_lines"
            CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
        fi
        
        # Check for parameter naming (should be camelCase)
        param_lines=$(grep -n "([^)]*[A-Z][a-zA-Z0-9]*[[:space:]]*[a-zA-Z0-9]*)" "$file" 2>/dev/null | head -3)
        if [ -n "$param_lines" ]; then
            while IFS= read -r param_line; do
                if [[ $param_line == *":"* ]] && [[ $param_line != *"class"* ]]; then
                    naming_violations_results="${naming_violations_results}$file:$param_line:Parameter should use camelCase\n"
                fi
            done <<< "$param_lines"
            CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
        fi
    fi
done < "$FILES_TO_ANALYZE"

if [ -n "$naming_violations_results" ]; then
    echo "#### 📝 **Naming Convention Violations**"
    echo ""
    echo "**C# Naming Standards:**"
    echo "- **Local variables:** camelCase (e.g., \`int health = 100;\`)"
    echo "- **Constants:** ALL_CAPS (e.g., \`const int MAX_HEALTH;\`)"
    echo "- **Member variables:** _underscore prefix (e.g., \`int _count = 5;\`)"
    echo "- **Public fields/Properties:** PascalCase (e.g., \`int Score = 100;\`)"
    echo "- **Methods/Classes:** PascalCase"
    echo ""
    echo "| File | Line | Issue | Code |"
    echo "|------|------|-------|------|"
    echo -e "$naming_violations_results" | while IFS= read -r line; do
        if [[ $line == *":"* ]]; then
            file=$(echo "$line" | cut -d: -f1)
            line_num=$(echo "$line" | cut -d: -f2)
            issue=$(echo "$line" | cut -d: -f4)
            code=$(echo "$line" | cut -d: -f3 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            echo "| \`$(basename "$file")\` | **$line_num** | $issue | \`$code\` |"
        fi
    done
    echo ""
    echo "> ⚠️ **Impact:** Poor code readability and inconsistent naming conventions"
    echo ""
fi

# Check for file size violations
large_file_results=""
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        line_count=$(wc -l < "$file" 2>/dev/null || echo "0")
        if [ "$line_count" -gt "$FILE_SIZE_LINES" ]; then
            large_file_results="${large_file_results}$(basename "$file"):$line_count:File exceeds $FILE_SIZE_LINES lines\n"
            CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
        fi
    fi
done < "$FILES_TO_ANALYZE"

if [ -n "$large_file_results" ]; then
    echo "#### 📏 **Large File Violations**"
    echo ""
    echo "| File | Lines | Issue |"
    echo "|------|-------|-------|"
    echo -e "$large_file_results" | while IFS= read -r line; do
        if [[ $line == *":"* ]]; then
            file=$(echo "$line" | cut -d: -f1)
            line_count=$(echo "$line" | cut -d: -f2)
            echo "| \`$file\` | **$line_count** | Exceeds $FILE_SIZE_LINES line limit |"
        fi
    done
    echo ""
    echo "> ⚠️ **Impact:** Large files are harder to maintain and understand"
    echo ""
fi

if [ "$CRITICAL_ISSUES" -eq 0 ]; then
    echo "#### ✅ **No critical issues found** 🎉"
    echo ""
    echo "> 💚 All analyzed code passes critical issue checks!"
    echo ""
fi

echo ""
echo "### ⚠️ **WARNINGS (POTENTIAL ISSUES)** ⚠️"
echo ""

# Check for GameObject.Find usage (general, not just in Update)
find_results=""
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        find_lines=$(grep -n "GameObject\.Find\|FindObjectOfType" "$file" 2>/dev/null | head -5)
        if [ -n "$find_lines" ]; then
            while IFS= read -r find_line; do
                if [[ $find_line == *":"* ]]; then
                    find_results="${find_results}$file:$find_line\n"
                fi
            done <<< "$find_lines"
            WARNING_ISSUES=$((WARNING_ISSUES + 1))
        fi
    fi
done < "$FILES_TO_ANALYZE"

if [ -n "$find_results" ]; then
    echo "#### 🔍 **GameObject.Find usage**"
    echo "*Consider caching these references for better performance*"
    echo ""
    echo "| File | Line | Method Used |"
    echo "|------|------|-------------|"
    echo -e "$find_results" | while IFS= read -r line; do
        if [[ $line == *":"* ]]; then
            file=$(echo "$line" | cut -d: -f1)
            line_num=$(echo "$line" | cut -d: -f2)
            code=$(echo "$line" | cut -d: -f3- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            echo "| \`$(basename "$file")\` | **$line_num** | \`$code\` |"
        fi
    done
    echo ""
fi

# Check for public field initialization
public_init_results=""
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        public_lines=$(grep -n "public.*=.*new" "$file" 2>/dev/null | head -5)
        if [ -n "$public_lines" ]; then
            while IFS= read -r public_line; do
                if [[ $public_line == *":"* ]]; then
                    public_init_results="${public_init_results}$file:$public_line\n"
                fi
            done <<< "$public_lines"
            WARNING_ISSUES=$((WARNING_ISSUES + 1))
        fi
    fi
done < "$FILES_TO_ANALYZE"

if [ -n "$public_init_results" ]; then
    echo "#### 🔒 **Public field initialization**"
    echo "*Consider using [SerializeField] private fields instead*"
    echo ""
    echo "| File | Line | Declaration |"
    echo "|------|------|-------------|"
    echo -e "$public_init_results" | while IFS= read -r line; do
        if [[ $line == *":"* ]]; then
            file=$(echo "$line" | cut -d: -f1)
            line_num=$(echo "$line" | cut -d: -f2)
            code=$(echo "$line" | cut -d: -f3- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            echo "| \`$(basename "$file")\` | **$line_num** | \`$code\` |"
        fi
    done
    echo ""
fi

# Check for missing namespace declarations
namespace_results=""
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        if grep -q "class\|struct\|interface\|enum" "$file" 2>/dev/null && ! grep -q "namespace" "$file" 2>/dev/null; then
            namespace_results="${namespace_results}$(basename "$file")\n"
            WARNING_ISSUES=$((WARNING_ISSUES + 1))
        fi
    fi
done < "$FILES_TO_ANALYZE"

if [ -n "$namespace_results" ]; then
    echo "#### 📁 **Missing namespace declarations**"
    echo "*C# scripts should be wrapped in namespaces*"
    echo ""
    echo "| File |"
    echo "|------|"
    echo -e "$namespace_results" | while IFS= read -r file; do
        if [ -n "$file" ]; then
            echo "| \`$file\` |"
        fi
    done
    echo ""
fi

# Check for magic numbers
magic_numbers_results=""
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        magic_lines=$(grep -n "\b[0-9]\{3,\}\b" "$file" 2>/dev/null | grep -v "//\|/\*" | head -5)
        if [ -n "$magic_lines" ]; then
            while IFS= read -r magic_line; do
                if [[ $magic_line == *":"* ]]; then
                    magic_numbers_results="${magic_numbers_results}$file:$magic_line\n"
                fi
            done <<< "$magic_lines"
            WARNING_ISSUES=$((WARNING_ISSUES + 1))
        fi
    fi
done < "$FILES_TO_ANALYZE"

if [ -n "$magic_numbers_results" ]; then
    echo "#### 🔢 **Hardcoded numbers detected**"
    echo "*Consider using named constants for large numbers*"
    echo ""
    echo "| File | Line | Value |"
    echo "|------|------|-------|"
    echo -e "$magic_numbers_results" | while IFS= read -r line; do
        if [[ $line == *":"* ]]; then
            file=$(echo "$line" | cut -d: -f1)
            line_num=$(echo "$line" | cut -d: -f2)
            code=$(echo "$line" | cut -d: -f3- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            echo "| \`$(basename "$file")\` | **$line_num** | \`$code\` |"
        fi
    done
    echo ""
fi

# Check for empty catch blocks
empty_catch_results=""
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        empty_catch_lines=$(grep -n -A2 "catch" "$file" 2>/dev/null | grep -B2 "^\s*}\s*$" | grep "catch" | head -3)
        if [ -n "$empty_catch_lines" ]; then
            while IFS= read -r catch_line; do
                if [[ $catch_line == *":"* ]]; then
                    empty_catch_results="${empty_catch_results}$file:$catch_line\n"
                fi
            done <<< "$empty_catch_lines"
            WARNING_ISSUES=$((WARNING_ISSUES + 1))
        fi
    fi
done < "$FILES_TO_ANALYZE"

if [ -n "$empty_catch_results" ]; then
    echo "#### 🕳️ **Empty catch blocks**"
    echo "*Silent exception swallowing - add logging or proper handling*"
    echo ""
    echo "| File | Line | Issue |"
    echo "|------|------|-------|"
    echo -e "$empty_catch_results" | while IFS= read -r line; do
        if [[ $line == *":"* ]]; then
            file=$(echo "$line" | cut -d: -f1)
            line_num=$(echo "$line" | cut -d: -f2)
            echo "| \`$(basename "$file")\` | **$line_num** | Empty catch block detected |"
        fi
    done
    echo ""
fi

# Check for hardcoded file paths
hardcoded_paths_results=""
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        path_lines=$(grep -n "Application\.dataPath.*+.*\"\|Application\.persistentDataPath.*+.*\"" "$file" 2>/dev/null | head -3)
        if [ -n "$path_lines" ]; then
            while IFS= read -r path_line; do
                if [[ $path_line == *":"* ]]; then
                    hardcoded_paths_results="${hardcoded_paths_results}$file:$path_line\n"
                fi
            done <<< "$path_lines"
            WARNING_ISSUES=$((WARNING_ISSUES + 1))
        fi
    fi
done < "$FILES_TO_ANALYZE"

if [ -n "$hardcoded_paths_results" ]; then
    echo "#### 📁 **Hardcoded file paths**"
    echo "*Use Path.Combine() for cross-platform compatibility*"
    echo ""
    echo "| File | Line | Path Usage |"
    echo "|------|------|------------|"
    echo -e "$hardcoded_paths_results" | while IFS= read -r line; do
        if [[ $line == *":"* ]]; then
            file=$(echo "$line" | cut -d: -f1)
            line_num=$(echo "$line" | cut -d: -f2)
            code=$(echo "$line" | cut -d: -f3- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            echo "| \`$(basename "$file")\` | **$line_num** | \`$code\` |"
        fi
    done
    echo ""
fi

# Check for missing SerializeField attribute
missing_serializefield_results=""
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        serialize_lines=$(grep -n "public.*GameObject\|public.*Transform\|public.*Rigidbody" "$file" 2>/dev/null | head -5)
        if [ -n "$serialize_lines" ] && ! grep -q "\[SerializeField\]" "$file" 2>/dev/null; then
            while IFS= read -r serialize_line; do
                if [[ $serialize_line == *":"* ]]; then
                    missing_serializefield_results="${missing_serializefield_results}$file:$serialize_line\n"
                fi
            done <<< "$serialize_lines"
            WARNING_ISSUES=$((WARNING_ISSUES + 1))
        fi
    fi
done < "$FILES_TO_ANALYZE"

if [ -n "$missing_serializefield_results" ]; then
    echo "#### 🔒 **Public Unity fields without SerializeField**"
    echo "*Consider making fields private and using [SerializeField] for better encapsulation*"
    echo ""
    echo "| File | Line | Field |"
    echo "|------|------|-------|"
    echo -e "$missing_serializefield_results" | while IFS= read -r line; do
        if [[ $line == *":"* ]]; then
            file=$(echo "$line" | cut -d: -f1)
            line_num=$(echo "$line" | cut -d: -f2)
            code=$(echo "$line" | cut -d: -f3- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            echo "| \`$(basename "$file")\` | **$line_num** | \`$code\` |"
        fi
    done
    echo ""
fi

# Check for missing regions in large files
missing_regions_results=""
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        line_count=$(wc -l < "$file" 2>/dev/null || echo "0")
        if [ "$line_count" -gt "$SUGGEST_REGIONS_LINES" ]; then
            if ! grep -q "#region\|#endregion" "$file" 2>/dev/null; then
                missing_regions_results="${missing_regions_results}$(basename "$file"):$line_count:Large file without regions\n"
                WARNING_ISSUES=$((WARNING_ISSUES + 1))
            fi
        fi
    fi
done < "$FILES_TO_ANALYZE"

if [ -n "$missing_regions_results" ]; then
    echo "#### 📁 **Missing Regions in Large Files**"
    echo "*Large files should use regions for better organization*"
    echo ""
    echo "| File | Lines | Suggestion |"
    echo "|------|-------|------------|"
    echo -e "$missing_regions_results" | while IFS= read -r line; do
        if [[ $line == *":"* ]]; then
            file=$(echo "$line" | cut -d: -f1)
            line_count=$(echo "$line" | cut -d: -f2)
            echo "| \`$file\` | **$line_count** | Add #region blocks for organization |"
        fi
    done
    echo ""
fi

# Check for missing XML documentation
missing_docs_results=""
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        public_methods=$(grep -n "public.*(" "$file" 2>/dev/null | wc -l)
        xml_docs=$(grep -n "///" "$file" 2>/dev/null | wc -l)
        if [ "$public_methods" -gt 0 ] && [ "$xml_docs" -eq 0 ]; then
            missing_docs_results="${missing_docs_results}$(basename "$file"):$public_methods:No XML documentation\n"
            WARNING_ISSUES=$((WARNING_ISSUES + 1))
        fi
    fi
done < "$FILES_TO_ANALYZE"

if [ -n "$missing_docs_results" ]; then
    echo "#### 📖 **Missing XML Documentation**"
    echo "*Public methods should have XML documentation*"
    echo ""
    echo "| File | Public Methods | Issue |"
    echo "|------|----------------|-------|"
    echo -e "$missing_docs_results" | while IFS= read -r line; do
        if [[ $line == *":"* ]]; then
            file=$(echo "$line" | cut -d: -f1)
            method_count=$(echo "$line" | cut -d: -f2)
            echo "| \`$file\` | **$method_count** | Missing /// XML docs |"
        fi
    done
    echo ""
fi

# Check for coroutine lifecycle issues
coroutine_issues_results=""
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        if grep -q "StartCoroutine" "$file" 2>/dev/null; then
            if ! grep -q "StopCoroutine\|StopAllCoroutines" "$file" 2>/dev/null; then
                coroutine_line=$(grep -n "StartCoroutine" "$file" 2>/dev/null | head -1 | cut -d: -f1)
                coroutine_issues_results="${coroutine_issues_results}$(basename "$file"):$coroutine_line:Coroutine started without stop mechanism\n"
                WARNING_ISSUES=$((WARNING_ISSUES + 1))
            fi
        fi
    fi
done < "$FILES_TO_ANALYZE"

if [ -n "$coroutine_issues_results" ]; then
    echo "#### 🔄 **Coroutine Lifecycle Issues**"
    echo "*Coroutines should have proper cleanup mechanisms*"
    echo ""
    echo "| File | Line | Issue |"
    echo "|------|------|-------|"
    echo -e "$coroutine_issues_results" | while IFS= read -r line; do
        if [[ $line == *":"* ]]; then
            file=$(echo "$line" | cut -d: -f1)
            line_num=$(echo "$line" | cut -d: -f2)
            echo "| \`$file\` | **$line_num** | StartCoroutine without stop mechanism |"
        fi
    done
    echo ""
fi

# Check for singleton overuse
singleton_issues_results=""
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        singleton_patterns=$(grep -n "Instance.*=\|\.Instance\|static.*Instance" "$file" 2>/dev/null | wc -l)
        if [ "$singleton_patterns" -gt 2 ]; then
            singleton_issues_results="${singleton_issues_results}$(basename "$file"):$singleton_patterns:Multiple singleton patterns\n"
            WARNING_ISSUES=$((WARNING_ISSUES + 1))
        fi
    fi
done < "$FILES_TO_ANALYZE"

if [ -n "$singleton_issues_results" ]; then
    echo "#### 🔒 **Potential Singleton Overuse**"
    echo "*Too many singleton patterns may indicate tight coupling*"
    echo ""
    echo "| File | Patterns | Issue |"
    echo "|------|----------|-------|"
    echo -e "$singleton_issues_results" | while IFS= read -r line; do
        if [[ $line == *":"* ]]; then
            file=$(echo "$line" | cut -d: -f1)
            pattern_count=$(echo "$line" | cut -d: -f2)
            echo "| \`$file\` | **$pattern_count** | Multiple singleton references detected |"
        fi
    done
    echo ""
fi

# Check for interface usage
interface_implementations=0
total_classes=0
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        class_count=$(grep "class.*:" "$file" 2>/dev/null | wc -l)
        interface_count=$(grep "class.*: .*I[A-Z]" "$file" 2>/dev/null | wc -l)
        
        total_classes=$((total_classes + class_count))
        interface_implementations=$((interface_implementations + interface_count))
    fi
done < "$FILES_TO_ANALYZE"

if [ "$total_classes" -gt 0 ]; then
    interface_ratio=$((interface_implementations * 100 / total_classes))
    if [ "$interface_ratio" -lt 20 ]; then
        echo "#### 🔌 **Low Interface Usage**"
        echo "*Consider using interfaces for better testability and decoupling*"
        echo ""
        echo "| Metric | Count | Ratio |"
        echo "|--------|-------|-------|"
        echo "| Total Classes | **$total_classes** | 100% |"
        echo "| Interface Implementations | **$interface_implementations** | **$interface_ratio%** |"
        echo ""
        echo "> 💡 **Suggestion:** Aim for 30%+ interface usage in business logic classes"
        echo ""
        WARNING_ISSUES=$((WARNING_ISSUES + 1))
    fi
fi

# Check for Unity Events usage
unity_events_results=""
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        event_count1=$(safe_grep_count "UnityEvent" "$file")
        event_count2=$(safe_grep_count "UnityAction" "$file")
        event_count=$((event_count1 + event_count2))
        
        action_count1=$(safe_grep_count "System\.Action" "$file")
        action_count2=$(safe_grep_count "Action<" "$file")
        action_count=$((action_count1 + action_count2))
        
        if [ "$action_count" -gt 0 ] && [ "$event_count" -eq 0 ]; then
            unity_events_results="${unity_events_results}$(basename "$file"):$action_count:Using Action instead of UnityEvent\n"
        fi
    fi
done < "$FILES_TO_ANALYZE"

if [ -n "$unity_events_results" ]; then
    echo "#### 🎯 **Unity Events Usage**"
    echo "*Consider UnityEvent for inspector-visible events*"
    echo ""
    echo "| File | Actions | Suggestion |"
    echo "|------|---------|------------|"
    echo -e "$unity_events_results" | while IFS= read -r line; do
        if [[ $line == *":"* ]]; then
            file=$(echo "$line" | cut -d: -f1)
            action_count=$(echo "$line" | cut -d: -f2)
            echo "| \`$file\` | **$action_count** | Consider UnityEvent for inspector events |"
        fi
    done
    echo ""
fi

# Check for excessive field count
large_class_results=""
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        private_fields=$(safe_grep_count "private.*;" "$file")
        public_fields=$(safe_grep_count "public.*;" "$file")
        protected_fields=$(safe_grep_count "protected.*;" "$file")
        field_count=$((private_fields + public_fields + protected_fields))
        
        if [ "$field_count" -gt 20 ]; then
            large_class_results="${large_class_results}$(basename "$file"):$field_count:Too many fields\n"
            WARNING_ISSUES=$((WARNING_ISSUES + 1))
        fi
    fi
done < "$FILES_TO_ANALYZE"

if [ -n "$large_class_results" ]; then
    echo "#### 📊 **Classes with Too Many Fields**"
    echo "*Classes with many fields may need refactoring*"
    echo ""
    echo "| File | Fields | Issue |"
    echo "|------|--------|-------|"
    echo -e "$large_class_results" | while IFS= read -r line; do
        if [[ $line == *":"* ]]; then
            file=$(echo "$line" | cut -d: -f1)
            field_count=$(echo "$line" | cut -d: -f2)
            echo "| \`$file\` | **$field_count** | Exceeds 20 field limit |"
        fi
    done
    echo ""
fi

if [ "$WARNING_ISSUES" -eq 0 ]; then
    echo "#### ✅ **No warnings found** 🎉"
    echo ""
    echo "> 💛 Code follows good warning-free practices!"
    echo ""
fi

echo ""
echo "### ℹ️ **INFO (CODE QUALITY METRICS)** ℹ️"
echo ""

# Calculate complexity metrics
total_methods=0
complex_methods=0
total_cyclomatic_complexity=0

while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        # Count methods (simple heuristic) - count each pattern separately
        public_methods=$(grep "public.*(" "$file" 2>/dev/null | wc -l)
        private_methods=$(grep "private.*(" "$file" 2>/dev/null | wc -l)  
        protected_methods=$(grep "protected.*(" "$file" 2>/dev/null | wc -l)
        method_count=$((public_methods + private_methods + protected_methods))
        total_methods=$((total_methods + method_count))
        
        # Estimate cyclomatic complexity by counting decision points
        if_count=$(grep " if *(" "$file" 2>/dev/null | wc -l)
        while_count=$(grep " while *(" "$file" 2>/dev/null | wc -l)
        for_count=$(grep " for *(" "$file" 2>/dev/null | wc -l)
        switch_count=$(grep " switch *(" "$file" 2>/dev/null | wc -l)
        catch_count=$(grep " catch *(" "$file" 2>/dev/null | wc -l)
        
        file_complexity=$((if_count + while_count + for_count + switch_count + catch_count + method_count))
        total_cyclomatic_complexity=$((total_cyclomatic_complexity + file_complexity))
        
        # Check for complex methods (rough estimation)
        if [ "$file_complexity" -gt 15 ] && [ "$method_count" -gt 0 ]; then
            avg_method_complexity=$((file_complexity / method_count))
            if [ "$avg_method_complexity" -gt 10 ]; then
                complex_methods=$((complex_methods + 1))
            fi
        fi
    fi
done < "$FILES_TO_ANALYZE"

# Calculate maintainability metrics
if [ "$total_methods" -gt 0 ]; then
    avg_complexity=$((total_cyclomatic_complexity / total_methods))
    complexity_ratio=$((complex_methods * 100 / total_methods))
    
    echo "#### 📊 **Code Complexity Analysis**"
    echo ""
    echo "| Metric | Value | Status |"
    echo "|--------|-------|--------|"
    echo "| Total Methods | **$total_methods** | ℹ️ Info |"
    echo "| Average Complexity | **$avg_complexity** | $([ $avg_complexity -lt 10 ] && echo '✅ Good' || echo '⚠️ High') |"
    echo "| Complex Methods | **$complex_methods** ($complexity_ratio%) | $([ $complexity_ratio -lt 10 ] && echo '✅ Good' || echo '⚠️ Review') |"
    echo "| Total Complexity | **$total_cyclomatic_complexity** | ℹ️ Cumulative |"
    echo ""
else
    echo "#### 📊 **Code Complexity Analysis**"
    echo ""
    echo "| Metric | Value | Status |"
    echo "|--------|-------|--------|"
    echo "| Total Methods | **0** | ℹ️ No methods found |"
    echo ""
fi

# Performance monitoring indicators
allocation_indicators=0
gc_pressure_indicators=0

while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        # Track allocation indicators
        new_count=$(grep " new " "$file" 2>/dev/null | wc -l)
        tostring_count=$(grep "\.ToString()" "$file" 2>/dev/null | wc -l)
        concatenation_count=$(grep '\+.*".*"' "$file" 2>/dev/null | wc -l)
        
        allocation_indicators=$((allocation_indicators + new_count + tostring_count + concatenation_count))
        
        # GC pressure indicators
        list_add_count=$(grep "\.Add(" "$file" 2>/dev/null | wc -l)
        array_resize_count=$(grep "Array\.Resize" "$file" 2>/dev/null | wc -l)
        list_new_count=$(grep "List.*= *new" "$file" 2>/dev/null | wc -l)
        
        gc_pressure_indicators=$((gc_pressure_indicators + list_add_count + array_resize_count + list_new_count))
    fi
done < "$FILES_TO_ANALYZE"

if [ "$allocation_indicators" -gt 0 ] || [ "$gc_pressure_indicators" -gt 0 ]; then
    echo "#### 🚀 **Performance Monitoring**"
    echo ""
    echo "| Metric | Count | Threshold | Impact |"
    echo "|--------|-------|-----------|--------|"
    echo "| Allocation Indicators | **$allocation_indicators** | $ALLOCATION_THRESHOLD | $([ $allocation_indicators -lt $ALLOCATION_THRESHOLD ] && echo '✅ Low' || echo '⚠️ Monitor') |"
    echo "| GC Pressure Indicators | **$gc_pressure_indicators** | $GC_PRESSURE_THRESHOLD | $([ $gc_pressure_indicators -lt $GC_PRESSURE_THRESHOLD ] && echo '✅ Low' || echo '⚠️ Monitor') |"
    echo ""
    echo "> 💡 **Note:** These are estimates based on code patterns. Use Unity Profiler for accurate measurements."
    echo ""
    echo "**Performance Pattern Analysis:**"
    echo "- **Memory Allocations:** new operators, ToString() calls, string concatenations"
    echo "- **GC Pressure:** List.Add(), Array.Resize(), collection reallocations"
    echo "- **Recommendations:** Cache references, use object pooling, avoid allocations in Update()"
    echo ""
fi

# Code quality summary
echo "#### 🎯 **Quality Summary**"
echo ""
quality_indicators=0
[ "$avg_complexity" -lt 10 ] && quality_indicators=$((quality_indicators + 1))
[ "$complexity_ratio" -lt 10 ] && quality_indicators=$((quality_indicators + 1))
[ "$allocation_indicators" -lt $ALLOCATION_THRESHOLD ] && quality_indicators=$((quality_indicators + 1))
[ "$gc_pressure_indicators" -lt $GC_PRESSURE_THRESHOLD ] && quality_indicators=$((quality_indicators + 1))

echo "| Quality Aspect | Status | Threshold |"
echo "|----------------|--------|-----------|"
echo "| Code Complexity | $([ "$avg_complexity" -lt 10 ] && echo '✅ Good' || echo '⚠️ Needs Review') | < 10 avg |"
echo "| Method Distribution | $([ "$complexity_ratio" -lt 10 ] && echo '✅ Well Distributed' || echo '⚠️ Some Complex Methods') | < 10% complex |"
echo "| Memory Allocation | $([ "$allocation_indicators" -lt $ALLOCATION_THRESHOLD ] && echo '✅ Conservative' || echo '⚠️ Monitor Usage') | < $ALLOCATION_THRESHOLD patterns |"
echo "| GC Pressure | $([ "$gc_pressure_indicators" -lt $GC_PRESSURE_THRESHOLD ] && echo '✅ Low Impact' || echo '⚠️ Potential Issues') | < $GC_PRESSURE_THRESHOLD indicators |"
echo ""

# Naming convention guidelines
echo "#### 📋 **C# Naming Convention Reference**"
echo ""
echo "| Context | Convention | Example | Correct Usage |"
echo "|---------|------------|---------|---------------|"
echo "| **Local Variables** | camelCase | \`int health = 100;\` | ✅ Small initial letter |"
echo "| **Constants** | ALL_CAPS | \`const int MAX_HEALTH;\` | ✅ All uppercase with underscores |"
echo "| **Member Variables** | _underscore | \`int _count = 5;\` | ✅ Underscore prefix for class fields |"
echo "| **Public Properties** | PascalCase | \`int Score { get; set; }\` | ✅ Capital initial letter |"
echo "| **Methods** | PascalCase | \`void StartGame()\` | ✅ Capital initial letter |"
echo "| **Classes** | PascalCase | \`class PlayerController\` | ✅ Capital initial letter, no underscores |"
echo "| **Parameters** | camelCase | \`void Move(float speed)\` | ✅ Small initial letter |"
echo ""
echo "#### 🎮 **Unity-Specific Class Naming Guidelines**"
echo ""
echo "| Class Type | Pattern | Example | Usage |"
echo "|------------|---------|---------|-------|"
echo "| **MonoBehaviour** | PascalCase + Controller/Manager | \`PlayerController\` | ✅ For Unity components |"
echo "| **ScriptableObject** | PascalCase + Data/Settings | \`WeaponData\` | ✅ For data assets |"
echo "| **Singleton** | PascalCase + Manager | \`GameManager\` | ✅ For global managers |"
echo "| **Interfaces** | IPascalCase | \`IMovable\` | ✅ Start with 'I' prefix |"
echo "| **Events/Delegates** | PascalCase + Event | \`PlayerDeathEvent\` | ✅ Descriptive event names |"
echo ""
echo "#### ❌ **Common Class Naming Mistakes**"
echo ""
echo "| Mistake | Example | Correct |"
echo "|---------|---------|---------|"
echo "| Lowercase start | \`playerController\` | \`PlayerController\` |"
echo "| Underscores | \`player_controller\` | \`PlayerController\` |"
echo "| All caps | \`PLAYERCONTROLLER\` | \`PlayerController\` |"
echo "| Abbreviations | \`PC\` | \`PlayerController\` |"
echo ""
echo "> 💡 **Best Practice:** Use descriptive, readable class names that clearly indicate their purpose"
echo ""

echo ""
echo "## 🚀 **COMPREHENSIVE UNITY CODE ANALYSIS COMPLETE** 🎯"
echo ""

# Calculate quality score
quality_score=100
quality_score=$((quality_score - (CRITICAL_ISSUES * 10)))
quality_score=$((quality_score - (WARNING_ISSUES * 2)))
[ $quality_score -lt 0 ] && quality_score=0

echo "### 📊 **Final Code Quality Report**"
echo ""
echo "| **Metric** | **Count** | **Impact** |"
echo "|------------|-----------|------------|"
echo "| 📁 **Total C# Files Analyzed** | **$file_count** | ℹ️ Scope |"
echo "| 🔴 **Critical Issues** | **$CRITICAL_ISSUES** | $([ $CRITICAL_ISSUES -eq 0 ] && echo '✅ Excellent' || echo '⚠️ Immediate attention required') |"
echo "| 🟡 **Warning Issues** | **$WARNING_ISSUES** | $([ $WARNING_ISSUES -lt 5 ] && echo '✅ Good' || echo '⚠️ Review recommended') |"
echo "| 🎯 **Quality Score** | **$quality_score/100** | $([ $quality_score -ge 90 ] && echo '🏆 Excellent' || [ $quality_score -ge 70 ] && echo '✅ Good' || [ $quality_score -ge 50 ] && echo '⚠️ Needs Improvement' || echo '🚨 Critical Issues Found') |"
echo ""

echo "### 🎯 **Key Recommendations**"
echo ""
if [ "$CRITICAL_ISSUES" -gt 0 ]; then
    echo "- 🔴 **Priority 1:** Address critical performance issues immediately"
fi
if [ "$WARNING_ISSUES" -gt 0 ]; then
    echo "- 🟡 **Priority 2:** Review and fix warning-level issues"
fi
echo "- 📝 **Code Quality:** Follow Unity best practices and coding standards"
echo "- 🚀 **Performance:** Cache references and avoid expensive operations in Update loops"
echo "- 🧪 **Testing:** Ensure proper null checking and error handling"
echo ""

echo "---"
echo ""
echo "*Report generated by Unity Code Analyzer on $(date '+%Y-%m-%d %H:%M:%S')*"
echo "*🤖 Powered by AI-driven code analysis for Unity projects*"

} > "$REPORT_FILE"

# Cleanup temporary files after report generation
rm -f "$FILES_TO_ANALYZE" 2>/dev/null || true

# Always exit successfully so the workflow can upload the report
exit 0
