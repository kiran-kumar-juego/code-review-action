# Unity Code Review Action for Gitea

A reusable GitHub Action for automated Unity C# code review with AI analysis, specifically designed to work with Gitea internal repositories.

## Features

- 🔍 Automated C# code analysis for Unity projects
- 🤖 AI-powered code review suggestions
- 📊 Comprehensive reporting on pull requests
- ⚡ Fast analysis with smart caching
- 🎯 Focuses on Unity-specific best practices
- 🏢 **Gitea Integration** - Works with internal Gitea repositories

## Gitea Setup Instructions

### Option 1: Use as Git Submodule (Recommended)

1. **Add this action as a submodule in your Unity project:**
   ```bash
   cd your-unity-project
   git submodule add https://internal-git.juegostudio.net/git/UnityProjects/code-review-action.git .github/actions/unity-code-review
   ```

2. **Create a workflow file** in your Unity project (`.github/workflows/code-review.yml`):
   ```yaml
   name: Unity Code Review
   
   on:
     pull_request:
       branches: [ master, main, development ]
       paths:
         - 'Assets/**/*.cs'
     workflow_dispatch:
       inputs:
         analyze_all_files:
           description: 'Analyze all C# files'
           required: false
           default: false
           type: boolean
   
   jobs:
     code-review:
       runs-on: ubuntu-latest
       permissions:
         contents: read
         pull-requests: write
         issues: write
         checks: write
   
       steps:
         - name: Checkout code with submodules
           uses: actions/checkout@v3
           with:
             fetch-depth: 0
             submodules: recursive
             token: ${{ secrets.GITEA_TOKEN }}  # If private repos
   
         - name: Run Unity Code Review
           uses: ./.github/actions/unity-code-review
           with:
             github-token: ${{ secrets.GITHUB_TOKEN }}
             analyze-all-files: ${{ github.event.inputs.analyze_all_files || false }}
             unity-version: '2022.3.0f1'
   ```

### Option 2: Direct Clone in Workflow

If you prefer not to use submodules:

```yaml
name: Unity Code Review

on:
  pull_request:
    branches: [ master, main, development ]
    paths:
      - 'Assets/**/*.cs'

jobs:
  code-review:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      issues: write
      checks: write

    steps:
      - name: Checkout Unity Project
        uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: Clone Code Review Action from Gitea
        run: |
          git clone https://internal-git.juegostudio.net/git/UnityProjects/code-review-action.git .github/actions/unity-code-review
        env:
          GIT_TOKEN: ${{ secrets.GITEA_TOKEN }}  # If authentication needed

      - name: Run Unity Code Review
        uses: ./.github/actions/unity-code-review
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          analyze-all-files: false
```

## Gitea Authentication Setup

### For Private Repositories

1. **Create a Personal Access Token in Gitea:**
   - Go to `https://internal-git.juegostudio.net/git/user/settings/applications`
   - Generate new token with repository permissions

2. **Add the token to your repository secrets:**
   - In your Unity project repository: Settings → Secrets → Actions
   - Add secret: `GITEA_TOKEN` with your token value

3. **Configure Git authentication in workflow:**
   ```yaml
   - name: Configure Git for Gitea
     run: |
       git config --global url."https://${{ secrets.GITEA_TOKEN }}@internal-git.juegostudio.net/".insteadOf "https://internal-git.juegostudio.net/"
   ```

## Gitea-Specific Features

### Pull Request Integration
This action is designed to work with Gitea's pull request system and will:
- Comment on pull requests with review results
- Create check runs for CI status
- Support Gitea's webhook system

### Repository Structure for Gitea
```
your-unity-project/
├── Assets/                           # Unity assets
├── .github/
│   ├── workflows/
│   │   └── code-review.yml          # Main workflow
│   └── actions/
│       └── unity-code-review/       # This action (as submodule)
│           ├── action.yml
│           ├── .github/
│           │   ├── scripts/
│           │   │   └── unity-analyzer.sh
│           │   └── unity-review-config.yml
│           └── README.md
└── ProjectSettings/                 # Unity project settings
```

## Configuration

Create a `.github/unity-review-config.yml` file in your Unity project to customize the review:

```yaml
file_patterns:
  include:
    - "Assets/**/*.cs"
  exclude:
    - "Assets/Plugins/**"
    - "Assets/ThirdParty/**"

review_settings:
  max_files_per_review: 20
  enable_ai_suggestions: true
  focus_areas:
    - performance
    - unity_best_practices
    - code_style
```

## Usage Examples

### Basic Usage (Public Repository)
```yaml
- uses: https://internal-git.juegostudio.net/git/kirankumar/code-review-action@master
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
```

### Advanced Usage with Custom Settings
```yaml
- uses: ./.github/actions/unity-code-review
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    analyze-all-files: true
    unity-version: '2023.1.0f1'
    dotnet-version: '7.0.x'
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `github-token` | GitHub/Gitea token for API access | Yes | - |
| `analyze-all-files` | Analyze all C# files instead of just changed files | No | `false` |
| `unity-version` | Unity version to use for analysis | No | `2022.3.0f1` |
| `dotnet-version` | .NET version to use | No | `6.0.x` |

## Outputs

| Output | Description |
|--------|-------------|
| `review-summary` | Summary of the code review results |
| `issues-found` | Number of issues found |

## Troubleshooting

### Common Gitea Issues

1. **Authentication Failed:**
   - Ensure `GITEA_TOKEN` is set correctly
   - Check token permissions in Gitea settings

2. **Submodule Clone Failed:**
   - Verify network access to internal Gitea server
   - Check repository permissions

3. **Workflow Not Triggering:**
   - Ensure webhook is configured in Gitea repository settings
   - Check branch protection rules

### Debug Mode
Enable debug logging by adding to your workflow:
```yaml
env:
  ACTIONS_STEP_DEBUG: true
```

## Contributing

This action is maintained internally. For issues or improvements:
1. Create an issue in the Gitea repository
2. Submit merge requests for enhancements
3. Follow internal code review processes

## License

Internal use license - see LICENSE file for details.
