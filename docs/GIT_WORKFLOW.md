# Git Workflow Guide

## Overview

This document defines the branching strategy, commit conventions, and pull request process for the Yalla Nemshi project.

---

## 🌳 Branching Strategy

We use **Git Flow** with the following branch structure:

### **Main Branches:**

#### **`main`** (Production)
- **Purpose:** Production-ready code only
- **Protection:** Requires pull request review + CI passing
- **Deployment:** Auto-deployed to production on merge
- **Naming:** Always `main` (never `master`)
- **Tag Format:** `v1.0.0`, `v1.0.1`, etc.

#### **`develop`** (Integration)
- **Purpose:** Development branch where features are integrated
- **Protection:** Requires pull request review + CI passing
- **Source for:** Feature branches, release branches
- **Deployment:** Deployed to staging on merge

### **Supporting Branches:**

#### **`feature/`** (Feature Development)
- **Naming:** `feature/CP-{issue-number}-brief-description`
- **Example:** `feature/CP-3-firebase-messaging`
- **Parent:** Branch from `develop`
- **Merge back:** To `develop` via pull request
- **Delete after:** Merge complete (auto-delete on PR)
- **Lifetime:** 1-2 weeks typical

#### **`bugfix/`** (Bug Fixes)
- **Naming:** `bugfix/issue-number-brief-description`
- **Example:** `bugfix/45-notification-crash`
- **Parent:** Branch from `develop`
- **Merge back:** To `develop` via pull request
- **Delete after:** Merge complete

#### **`hotfix/`** (Production Bugs)
- **Naming:** `hotfix/issue-number-brief-description`
- **Example:** `hotfix/12-auth-token-expiry`
- **Parent:** Branch from `main`
- **Merge back:** To `main` AND `develop` (two PRs)
- **Delete after:** Merge complete
- **Tag:** Create version tag after merging to `main`
- **Emergency:** Use only for critical production issues

#### **`release/`** (Release Preparation)
- **Naming:** `release/v{version}`
- **Example:** `release/v1.2.0`
- **Parent:** Branch from `develop`
- **Merge back:** To `main` AND `develop`
- **Purpose:** Version bump, final testing, release notes
- **Lifetime:** 1-3 days

---

## 📝 Commit Conventions

### **Commit Message Format:**

```
<type>(<scope>): <subject>

<body>

<footer>
```

### **Type (Required):**

| Type | Use Case |
|------|----------|
| `feat` | New feature or capability |
| `fix` | Bug fix |
| `docs` | Documentation changes |
| `style` | Code style (formatting, missing semicolons, etc.) |
| `refactor` | Code refactoring without feature/fix |
| `perf` | Performance improvements |
| `test` | Adding or updating tests |
| `chore` | Dependencies, build config, etc. |
| `ci` | CI/CD configuration changes |

### **Scope (Optional but Recommended):**

Dart files you modified:
- `notification_service` - Notification integration
- `home_screen` - Home screen UI
- `firestore_repository` - Database operations
- `auth_provider` - Authentication state
- etc.

### **Subject Rules:**

- Imperative mood: "add" not "adds" or "added"
- No period at end
- Lowercase first letter
- Max 50 characters
- If can't fit, it's too specific

### **Examples:**

**✅ Good:**
```
feat(notification_service): add FCM token refresh handler
fix(home_screen): resolve null pointer on empty walks list
docs(firebase): update security rules documentation
refactor(repositories): extract common query logic
perf(firestore): add indexes for walk queries
```

**❌ Bad:**
```
Fix stuff                           # Too vague
ADDED NEW FEATURE FOR NOTIFICATIONS # Too shouty
notification service changes        # Not imperative
added many new things and fixed bugs # Too broad
```

### **Body (Optional for small commits, Required for complex ones):**

- Wrapped at 72 characters
- Explain **what** and **why**, not **how**
- Separate from subject with blank line
- Reference issue numbers: `Fixes #123` or `Related to #45`

**Example:**
```
feat(auth): implement biometric authentication

Adds Flutter's local_auth plugin for fingerprint/face recognition
on supported devices. Falls back to password authentication if
biometric is unavailable or disabled.

Fixes #89
Related to CP-5 security enhancements
```

### **Footer (Optional):**

```
Fixes #issue-number
Closes #issue-number
Related to #issue-number
BREAKING CHANGE: describe what broke
```

---

## 🔀 Pull Request Process

### **Before Creating PR:**

1. ✅ Create feature branch from `develop`:
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/CP-XX-description
   ```

2. ✅ Make focused changes (one feature = one PR)

3. ✅ Test locally:
   ```bash
   flutter pub get
   flutter analyze
   flutter test          # if applicable
   flutter run -d chrome # or device
   ```

4. ✅ Push and verify no conflicts:
   ```bash
   git push -u origin feature/CP-XX-description
   ```

### **Creating the PR:**

**Title Format:** `[CP-{issue}] Brief Description`
- Example: `[CP-3] Implement Firebase Cloud Messaging`

**Description Template:**

```markdown
## Description
Brief summary of what this PR does and why.

## Type of Change
- [ ] New feature
- [ ] Bug fix
- [ ] Documentation update
- [ ] Refactoring
- [ ] Performance improvement

## Related Issue
Fixes #123

## Changes Made
- Specific change 1
- Specific change 2
- Specific change 3

## Testing
How was this tested? Include steps to reproduce if applicable.

## Screenshots (if applicable)
Include before/after screenshots for UI changes.

## Checklist
- [ ] Code follows project style guidelines
- [ ] Comments added for complex logic
- [ ] Documentation updated if needed
- [ ] No new warnings or errors introduced
- [ ] Tested locally
- [ ] Ready for review
```

### **Review Process:**

1. **Code Review:** Minimum 1 approval required
   - Look for code quality, logic correctness, style
   - Suggest improvements, ask clarifying questions
   
2. **CI Checks:** All automated checks must pass
   - `flutter analyze` (no warnings)
   - Unit tests (if applicable)
   - Build verification

3. **Approval:** PR author addresses all review comments
   - Update code based on feedback
   - Re-request review when ready

4. **Merge:** Squash commits and merge to parent branch
   - Merge button only available after approval + CI pass
   - Use "Squash and merge" to keep history clean
   - Delete branch after merge

---

## ⛔ Important Security Rules

### **NEVER commit to main:**
```bash
# ❌ Wrong - don't do this
git checkout main
git commit -m "quick fix"

# ✅ Right - create feature branch
git checkout -b hotfix/description
git commit -m "fix(scope): description"
```

### **NEVER commit secrets:**
```bash
# ❌ These go in .env or .gitignore
- Firebase admin SDK keys
- Google Maps API keys
- Private signing certificates
- Service account JSON files

# ✅ Check .gitignore for excluded patterns
cat .gitignore | grep -E "secrets|env|json|key"
```

### **NEVER force push to shared branches:**
```bash
# ❌ Never on main/develop
git push -f origin develop

# ✅ Force push only on personal feature branches if needed
git push -f origin feature/my-branch
```

### **NEVER merge without approval:**
```bash
# ❌ Self-merge without review
git merge feature/my-code
git push origin main

# ✅ Go through full PR process
# Create PR → Wait for review → Approve → Merge
```

---

## 🔄 Common Workflows

### **Starting a New Feature:**
```bash
# Update develop
git checkout develop
git pull origin develop

# Create feature branch
git checkout -b feature/CP-42-user-preferences

# Make changes, commit regularly
git add src/feature_file.dart
git commit -m "feat(preferences): add theme toggle"

# Push when ready for PR
git push -u origin feature/CP-42-user-preferences
```

### **Responding to PR Review:**
```bash
# After reviewer comments:
git add .
git commit -m "refactor: address review feedback"
git push origin feature/CP-42-user-preferences

# Re-request review on GitHub
```

### **Merging a Hotfix:**
```bash
# Create hotfix from main
git checkout main
git pull origin main
git checkout -b hotfix/auth-crash

# Fix, test, commit
git add lib/services/auth_service.dart
git commit -m "fix(auth): prevent crash on token expiry"

# Create PR to main
git push -u origin hotfix/auth-crash

# After merge to main, also merge to develop
git checkout develop
git pull origin develop
git merge main
git push origin develop
```

### **Creating a Release:**
```bash
# Create release branch
git checkout develop
git pull origin develop
git checkout -b release/v1.2.0

# Update version in pubspec.yaml
# Update CHANGELOG.md
git add pubspec.yaml CHANGELOG.md
git commit -m "chore(release): bump to v1.2.0"

# Create PR to main
git push -u origin release/v1.2.0

# After merge to main:
git checkout main
git pull origin main
git tag -a v1.2.0 -m "Release version 1.2.0"
git push origin v1.2.0

# Also merge back to develop
git checkout develop
git merge main
git push origin develop
```

---

## 📊 Branch Status

### **How to Check Current Status:**
```bash
# See all branches
git branch -a

# See branch tracking
git branch -vv

# See recent commits
git log --oneline -10

# See remote status
git fetch
git status
```

### **Cleanup Old Branches:**
```bash
# Delete local feature branch after merge
git branch -d feature/CP-42-completed

# Delete remote tracking branch
git push origin --delete feature/CP-42-completed

# Clean up stale remote tracking branches
git fetch --prune
```

---

## ⚠️ Troubleshooting

### **Issue: "Your branch is behind by X commits"**
```bash
# Update your branch
git fetch origin
git rebase origin/develop
git push -f origin feature/my-branch  # force-push own branch only
```

### **Issue: Merge Conflict**
```bash
# Example from this repo: merge conflict occurred in git history
git status                 # See conflicted files
git diff                   # Review changes
# Edit files to resolve conflicts
git add resolved_file.dart
git commit -m "refactor: resolve merge conflict"
git push origin feature/branch
```

### **Issue: Committed Sensitive Data**
```bash
# NEVER push if it contains secrets!
# Use git filter-repo (as done in this project's history)
git filter-repo --invert-paths --path path/to/secret.json
git push -f origin develop

# Then create new credentials
```

### **Issue: Wrong Branch for Commit**
```bash
# Committed to wrong branch? Cherry-pick it
git log --oneline                    # Find the commit hash
git checkout correct-branch
git cherry-pick abc123def            # Commit hash
git push origin correct-branch

# Remove from wrong branch
git checkout wrong-branch
git revert abc123def
git push origin wrong-branch
```

---

## 📚 Resources

- [Git Flow Cheatsheet](https://danielkummer.github.io/git-flow-cheatsheet/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub Flow Documentation](https://guides.github.com/introduction/flow/)
- [Flutter Best Practices](https://flutter.dev/docs/development/best-practices)

---

## 👥 Team Guidelines

### **For Solo Development:**
- Still use feature branches (good practice)
- Can self-approve PRs after own testing
- Merge when confident and CI passes

### **For Team Development:**
- Always wait for at least 1 peer review
- Address all comments before merging
- Don't merge your own PRs without approval
- Respect review feedback

### **For Code Review:**
- Be constructive and respectful
- Suggest improvements, don't demand
- Approve when quality meets project standards
- Flag breaking changes explicitly

---

**Last Updated:** January 15, 2026  
**Maintained By:** Yalla Nemshi Team
