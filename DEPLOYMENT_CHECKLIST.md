# Gitea Deployment Checklist

## ✅ Pre-deployment Steps

### 1. Repository Setup
- [ ] Repository created on Gitea: `https://internal-git.juegostudio.net/git/kirankumar/code-review-action`
- [ ] Repository visibility set appropriately (public/private)
- [ ] Actions enabled in repository settings

### 2. Action Configuration
- [ ] `action.yml` file is complete and valid
- [ ] Unity analyzer script is executable (`unity-analyzer.sh`)
- [ ] Configuration file exists (`unity-review-config.yml`)
- [ ] Documentation is updated (README.md, QUICK_SETUP.md)

### 3. Testing Setup
- [ ] Test Unity project available
- [ ] Test workflow created (`.github/workflows/test-action.yml`)

## ✅ Deployment Steps

### 1. Push to Gitea
```bash
# Initialize git if not already done
git init
git add .
git commit -m "Initial Unity code review action"

# Add Gitea remote
git remote add origin https://internal-git.juegostudio.net/git/UnityProjects/code-review-action.git

# Push to master/main branch
git push -u origin master
```

### 2. Create Release Tags
```bash
# Create initial release
git tag -a v1.0.0 -m "Initial release of Unity Code Review Action"
git push origin v1.0.0

# Create major version tag (for easier referencing)
git tag -a v1 -m "Version 1.x"
git push origin v1
```

### 3. Test the Action
```bash
# Clone in a test Unity project
cd /path/to/test-unity-project
git clone https://internal-git.juegostudio.net/git/UnityProjects/code-review-action.git .github/actions/unity-code-review

# Create test workflow and push
```

## ✅ Post-deployment Steps

### 1. Documentation Distribution
- [ ] Share QUICK_SETUP.md with development teams
- [ ] Add to internal wiki/documentation
- [ ] Create team training materials

### 2. Integration Testing
- [ ] Test with real Unity projects
- [ ] Verify pull request integration works
- [ ] Check Gitea webhook functionality
- [ ] Validate error handling

### 3. Team Onboarding
- [ ] Demo to development teams
- [ ] Create example implementations
- [ ] Set up support channels

## ✅ Maintenance Checklist

### Regular Updates
- [ ] Monitor action performance
- [ ] Update Unity version compatibility
- [ ] Improve analysis rules
- [ ] Handle user feedback

### Version Management
```bash
# For patch updates
git tag v1.0.1 && git push origin v1.0.1

# For minor updates
git tag v1.1.0 && git push origin v1.1.0
git tag -f v1 && git push origin v1 --force

# For major updates
git tag v2.0.0 && git push origin v2.0.0
git tag v2 && git push origin v2
```

## 📋 Usage Instructions for Teams

### Quick Implementation
Teams can add this to their Unity projects with:

```bash
# Method 1: Direct clone in workflow
# Add this step to .github/workflows/unity-review.yml:
- name: Get code review action
  run: git clone https://internal-git.juegostudio.net/git/UnityProjects/code-review-action.git .github/actions/unity-code-review

# Method 2: As submodule
git submodule add https://internal-git.juegostudio.net/git/UnityProjects/code-review-action.git .github/actions/unity-code-review
```

### Workflow Template
```yaml
name: Unity Code Review
on:
  pull_request:
    paths: ['Assets/**/*.cs']
jobs:
  review:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - run: git clone https://internal-git.juegostudio.net/git/UnityProjects/code-review-action.git .github/actions/unity-code-review
      - uses: ./.github/actions/unity-code-review
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

## 🔧 Troubleshooting

### Common Issues
1. **Clone fails**: Check repository permissions and network access
2. **Action not found**: Verify the clone step completed successfully
3. **Permission denied**: Ensure proper workflow permissions are set
4. **No files analyzed**: Check file paths and Unity project structure
5. **Script fails with exit code 1**: Check the Unity analyzer script for syntax errors

### Fixed Issues (August 2025)
#### Unity Analyzer Script Fixes
The following issues were identified and resolved in the Unity analyzer script:

1. **Input Delimiter Issue**: Fixed multiple `while` loops that were using `-d ''` (null delimiter) when reading newline-delimited files
   - **Files affected**: Lines using `while IFS= read -r -d '' file`
   - **Fix**: Changed to `while IFS= read -r file` for proper newline handling

2. **Missing Rule Category Parameters**: Added missing rule category and rule name parameters to `add_finding` calls
   - **Issue**: Many `add_finding` calls were missing the required 6th and 7th parameters
   - **Fix**: Added appropriate rule categories like "naming_conventions", "performance", "unity_best_practices", etc.

3. **YAML Parsing Issue**: Fixed namespace_prefix parsing from nested YAML structure
   - **Issue**: `parse_yaml` function couldn't handle nested YAML keys under `project:` section
   - **Fix**: Implemented proper AWK-based parsing for nested YAML values

4. **Duplicate Loop Processing**: Removed duplicate `done < "$FILES_TO_ANALYZE"` lines
   - **Issue**: Some sections had duplicate loop endings causing script errors
   - **Fix**: Cleaned up duplicate lines and ensured proper loop structure

#### Script Testing Results
After fixes, the script successfully:
- ✅ Loads configuration from `unity-review-config.yml`
- ✅ Processes C# files according to include/exclude patterns
- ✅ Generates detailed analysis reports with proper categorization
- ✅ Exits with code 0 on success, code 1 only when actual errors are found
- ✅ Provides actionable feedback with file names, line numbers, and suggestions

### Debug Mode
Add to workflow for detailed logging:
```yaml
env:
  ACTIONS_STEP_DEBUG: true
```

## 📞 Support

- **Repository**: https://internal-git.juegostudio.net/git/kirankumar/code-review-action
- **Issues**: Create issues in the Gitea repository
- **Documentation**: Check README.md and QUICK_SETUP.md
- **Contact**: kiran.kumar@juegostudioz.com
