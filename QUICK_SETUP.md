# Quick Setup Guide for Gitea Integration

## Step 1: Add this action to your Unity project

Choose one of these methods:

### Method A: As a Submodule (Recommended)
```bash
cd your-unity-project
git submodule add https://internal-git.juegostudio.net/git/kirankumar/code-review-action.git .github/actions/unity-code-review
git commit -m "Add Unity code review action"
```

### Method B: Direct clone in workflow
Use the workflow template below that clones the action automatically.

## Step 2: Create workflow file

Create `.github/workflows/unity-code-review.yml` in your Unity project:

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
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      # If using Method A (submodule), uncomment this:
      # - name: Update submodules
      #   run: git submodule update --init --recursive

      # If using Method B (direct clone), use this:
      - name: Clone code review action
        run: |
          git clone https://internal-git.juegostudio.net/git/kirankumar/code-review-action.git .github/actions/unity-code-review

      - name: Run Unity Code Review
        uses: ./.github/actions/unity-code-review
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          analyze-all-files: false
```

## Step 3: Configure Gitea Repository

1. **Enable Actions** in your Gitea repository:
   - Go to repository Settings → Actions
   - Enable Actions for this repository

2. **Set up webhooks** (if needed):
   - Repository Settings → Webhooks
   - Add webhook for push/pull request events

## Step 4: Test the setup

1. Create a test branch with some C# changes in Assets/
2. Open a pull request
3. Check the Actions tab to see the workflow running

## Troubleshooting

### Action not found
- Verify the clone URL is accessible
- Check if repository is public or if authentication is needed

### Permission errors
- Ensure the repository has Actions enabled
- Check workflow permissions in the YAML file

### No files analyzed
- Verify C# files are in the Assets/ folder
- Check the file path patterns in the workflow

## Advanced Configuration

Create `.github/unity-review-config.yml` in your Unity project:

```yaml
file_patterns:
  include:
    - "Assets/**/*.cs"
  exclude:
    - "Assets/Plugins/**"
    - "Assets/ThirdParty/**"

review_settings:
  max_files_per_review: 15
  enable_ai_suggestions: true
  focus_areas:
    - performance
    - unity_best_practices
    - memory_management
```
