# Unity Code Review Action

A reusable GitHub Action for automated Unity C# code review with AI analysis, designed for internal Gitea repositories.

## 🏢 Gitea Integration

This action is hosted on our internal Gitea server: `https://internal-git.juegostudio.net/git/kirankumar/code-review-action`

## Features

- 🔍 Automated C# code analysis for Unity projects
- 🤖 AI-powered code review suggestions
- 📊 Comprehensive reporting on pull requests
- ⚡ Fast analysis with smart caching
- 🎯 Focuses on Unity-specific best practices
- 🏢 **Gitea Compatible** - Works seamlessly with internal Gitea repositories

## Usage with Gitea

Since this action is hosted on an internal Gitea server, you have two main options:

### Option 1: Clone in Workflow (Recommended)

```yaml
name: Unity Code Review
on:
  pull_request:
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
      
      - name: Get Unity Code Review Action
        run: |
          git clone https://internal-git.juegostudio.net/git/UnityProjects/code-review-action.git .github/actions/unity-code-review
      
      - name: Run Unity Code Review
        uses: ./.github/actions/unity-code-review
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

### Option 2: Git Submodule

```bash
# Add as submodule
git submodule add https://internal-git.juegostudio.net/git/UnityProjects/code-review-action.git .github/actions/unity-code-review

# Then in your workflow:
- name: Checkout with submodules
  uses: actions/checkout@v4
  with:
    fetch-depth: 0
    submodules: recursive

- name: Run Unity Code Review
  uses: ./.github/actions/unity-code-review
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
```

### Advanced Usage

```yaml
- name: Run Unity Code Review
  uses: https://internal-git.juegostudio.net/git/kirankumar/code-review-action@master
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    analyze-all-files: 'true'
    unity-version: '2022.3.0f1'
    dotnet-version: '6.0.x'
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `github-token` | GitHub token for API access | Yes | - |
| `analyze-all-files` | Analyze all C# files instead of just changed files | No | `false` |
| `unity-version` | Unity version to use for analysis | No | `2022.3.0f1` |
| `dotnet-version` | .NET version to use | No | `6.0.x` |

## Outputs

| Output | Description |
|--------|-------------|
| `review-summary` | Summary of the code review results |
| `issues-found` | Number of issues found |

## Examples

### Use in Multiple Workflows

You can use this action in different scenarios:

1. **Pull Request Reviews** - Automatic review on PRs
2. **Manual Analysis** - On-demand analysis via workflow_dispatch
3. **Release Preparation** - Full codebase analysis before releases

### Customize for Your Project

```yaml
- name: Unity Code Review with Custom Settings
  uses: https://internal-git.juegostudio.net/git/kirankumar/code-review-action@master
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    analyze-all-files: ${{ github.event_name == 'workflow_dispatch' }}
    unity-version: '2023.1.0f1'
```

## Development

### Local Testing

To test this action locally:

1. Clone the repository
2. Create a test Unity project in the `test/` directory
3. Run the workflow using `act` or GitHub's local runner

### Contributing

1. Fork this repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

If you encounter any issues or have questions:
- Create an issue in this repository
- Check the existing issues for solutions
- Review the workflow logs for debugging information
