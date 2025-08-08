# Using Unity Code Review Action with Git Submodules

If you're using an internal Git server and want to include this action in your Unity projects, you can use Git submodules.

## Setup Instructions

1. **Add the action as a submodule in your Unity project:**
   ```bash
   git submodule add https://internal-git.juegostudio.net/git/UnityProjects/code-review-action.git .github/actions/unity-code-review
   ```

2. **Create a workflow in your Unity project** (`.github/workflows/code-review.yml`):
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
         - name: Checkout code with submodules
           uses: actions/checkout@v3
           with:
             fetch-depth: 0
             submodules: recursive
   
         - name: Run Unity Code Review
           uses: ./.github/actions/unity-code-review
           with:
             github-token: ${{ secrets.GITHUB_TOKEN }}
             analyze-all-files: 'false'
   ```

3. **Update submodule when action is updated:**
   ```bash
   git submodule update --remote .github/actions/unity-code-review
   git add .github/actions/unity-code-review
   git commit -m "Update code review action"
   ```

## Authentication for Internal Git

If your internal Git server requires authentication, you can:

1. **Use SSH keys:**
   ```bash
   git submodule add git@internal-git.juegostudio.net:kirankumar/code-review-action.git .github/actions/unity-code-review
   ```

2. **Use personal access tokens in CI:**
   Add the token as a secret and configure Git in your workflow:
   ```yaml
   - name: Configure git for internal server
     run: |
       git config --global url."https://${{ secrets.INTERNAL_GIT_TOKEN }}@internal-git.juegostudio.net/".insteadOf "https://internal-git.juegostudio.net/"
   ```

## Benefits of Submodule Approach

- ✅ Version control of the action version
- ✅ Works with internal Git servers
- ✅ No need for public repositories
- ✅ Easy to update across projects
- ✅ Offline development possible
