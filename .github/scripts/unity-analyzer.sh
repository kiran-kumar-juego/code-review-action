#!/bin/bash

# Beautiful Unity Code Analyzer with formatted output
# This script performs detailed analysis of Unity C# scripts for common issues and best practices

# Disable exit on error for analysis sections to prevent early termination
set +e

# Add debugging trap
trap 'echo "❌ Script failed at line $LINENO with command: $BASH_COMMAND" >&2' ERR

# Configuration defaults
NAMESPACE_PREFIX="MyProject"
MAX_GETCOMPONENT_CALLS=3
SUGGEST_REGIONS_LINES=50
FILE_SIZE_LINES=100

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration file path (relative to script location)
CONFIG_FILE="$SCRIPT_DIR/../unity-review-config.yml"

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

if [ "$WARNING_ISSUES" -eq 0 ]; then
    echo "#### ✅ **No warnings found** 🎉"
    echo ""
    echo "> 💛 Code follows good warning-free practices!"
    echo ""
fi

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
