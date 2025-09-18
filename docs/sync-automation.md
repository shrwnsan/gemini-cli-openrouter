# 🔄 Repository Sync Automation

This document explains how to use the automated sync system for keeping your OpenRouter fork updated with upstream changes.

## Overview

The sync automation system provides:

- **Automated backups** before every sync operation
- **Conflict detection** and notification
- **Flexible sync options** (full, main-only, feature-only)
- **GitHub release creation** for major syncs
- **Automatic PR creation** when feature updates are available
- **Automatic cleanup** of old backup branches

## Repository Structure

```
google-gemini/main ──────────────┐
    ↓ (sync)                     │
main (your fork) ────────────────┼─► origin/main
    │                            │
    ↓ (feature branch - mirror)  │
feature/openrouter-support ──────┘
    ↓ (sync)
upstream/feature/openrouter-support
```

### Branch Strategy

- **Main Branch**: Contains OpenRouter integration + sync automation

  - ✅ **Backed up** before sync operations
  - 🔄 Synced with `google-gemini/main`

- **Feature Branch**: Pure mirror of heartyguy's OpenRouter implementation
  - ❌ **Not backed up** (recreatable from upstream)
  - 🔄 Synced with `upstream/feature/openrouter-support` (heartyguy/gemini-cli)
  - Contains only upstream commit `dc9c49578`

### PR Creation Workflow

When heartyguy updates their feature branch:

1. **Sync Detection**: Automation detects new commits in upstream/feature (heartyguy/gemini-cli)
2. **Feature Sync**: Pulls updates to local feature/openrouter-support branch
3. **Conflict Check**: Verifies no merge conflicts with main branch
4. **PR Creation**: Automatically creates PR from feature to main (if `-p` flag used)
5. **Testing**: Runs build and OpenRouter tests before PR creation
6. **Notification**: Provides PR link for review and merge

**Manual PR Creation** (if automation fails):

```bash
# Create PR manually
gh pr create --title "feat: Update OpenRouter integration from upstream" \
             --body "Latest updates from upstream OpenRouter implementation" \
             --base main --head feature/openrouter-support
```

## Quick Start

### 1. Ensure Remotes are Configured

```bash
# Check current remotes
git remote -v

# Add if missing
git remote add google-gemini https://github.com/google-gemini/gemini-cli.git
git remote add upstream https://github.com/heartyguy/gemini-cli.git

# Fetch all remotes
git fetch --all
```

### 2. Test the System

```bash
# Dry run to see what would happen
./scripts/manual-sync.sh -d

# Test sync only main branch
./scripts/manual-sync.sh -t main-only -d

# Create PR if feature updates available
./scripts/manual-sync.sh -p

# Full sync with PR creation and release
./scripts/manual-sync.sh -r -p
```

## Usage Methods

### Method 1: GitHub Actions (Automated)

#### Weekly Automated Sync

- Runs automatically every Monday at 2 AM UTC
- Creates backups and syncs both branches
- Notifies on conflicts via GitHub Issues

#### Manual GitHub Actions

1. Go to **Actions** tab in your repository
2. Click **"Repository Sync with Backup"**
3. Click **"Run workflow"**
4. Choose sync type and options
5. Click **"Run workflow"**

### Method 2: Local Script (Manual)

#### Basic Usage

```bash
# Full sync (main + feature branches)
./scripts/manual-sync.sh

# Sync only main branch
./scripts/manual-sync.sh -t main-only

# Sync only feature branch
./scripts/manual-sync.sh -t feature-only

# Create release after successful sync
./scripts/manual-sync.sh -r

# Dry run (see what would happen)
./scripts/manual-sync.sh -d
```

#### Advanced Usage

```bash
# Sync main only with release
./scripts/manual-sync.sh -t main-only -r

# Dry run of feature sync
./scripts/manual-sync.sh -t feature-only -d

# Get help
./scripts/manual-sync.sh -h
```

## Workflow Details

### Sync Process

1. **Create Backups**: Backup branches are created with timestamp

   - `backup/main-pre-sync-YYYYMMDD-HHMMSS`
   - `backup/feature-pre-sync-YYYYMMDD-HHMMSS`

2. **Conflict Detection**: System checks for merge conflicts before attempting sync

3. **Sync Operation**:

   - Main branch: Merges with `google-gemini/main`
   - Feature branch: Merges with `upstream/feature/openrouter-support` (heartyguy/gemini-cli)

4. **Testing**: Runs OpenRouter-specific tests to ensure functionality

5. **Release Creation** (optional): Creates GitHub release with sync details

6. **Cleanup**: Old backup branches are automatically cleaned up monthly

### Conflict Resolution

When conflicts are detected:

1. **GitHub Actions**: Creates an issue with resolution instructions
2. **Local Script**: Provides manual resolution commands

**Resolution Steps:**

```bash
# Check conflicted files
git status

# Edit conflicted files manually
# Resolve conflicts by choosing appropriate changes

# Stage resolved files
git add <resolved-files>

# Commit resolution
git commit -m "Resolve sync conflicts"

# Push resolved changes
git push origin <branch-name>
```

## Backup Strategy

### Backup Branches

- Created before every sync operation
- Named with timestamp: `backup/{branch}-pre-sync-{timestamp}`
- Kept for rollback purposes
- Automatically cleaned up (keeps last 5 per branch type)

### Rollback Process

```bash
# If you need to rollback
git checkout backup/main-pre-sync-20241201-143022
git checkout -b main-rollback
git push origin main-rollback

# Then create a PR to merge back to main
```

## Monitoring and Maintenance

### Regular Tasks

#### Weekly (Automated)

- Full sync runs automatically every Monday
- Backup cleanup runs monthly on the 1st

#### Manual Checks

```bash
# Check backup branches
git branch -r | grep backup/

# Check recent sync status
git log --oneline --grep="sync" -10

# Check for conflicts in recent merges
git log --oneline --grep="conflict" -10
```

### Troubleshooting

#### Common Issues

**"Remote not found" errors:**

```bash
# Re-add remotes
git remote add google-gemini https://github.com/google-gemini/gemini-cli.git
git remote add upstream https://github.com/heartyguy/gemini-cli.git
```

**Permission errors:**

- Ensure `GITHUB_TOKEN` has `contents: write` permission
- Check repository settings for Actions permissions

**Test failures:**

- Review test output for OpenRouter-specific issues
- May indicate breaking changes in upstream

#### Emergency Procedures

**If sync goes wrong:**

1. Check backup branches: `git branch -r | grep backup/`
2. Rollback to backup: `git checkout backup/main-pre-sync-{timestamp}`
3. Create recovery branch: `git checkout -b main-recovery`
4. Manually resolve issues and create PR

## Configuration

### GitHub Actions Settings

**Required Permissions:**

- `contents: write` - For creating branches and releases
- `pull-requests: write` - For creating conflict notification issues

**Schedule Customization:**
Edit `.github/workflows/sync-backup.yml`:

```yaml
schedule:
  - cron: '0 2 * * 1' # Monday 2 AM UTC
```

### Script Configuration

**Default Settings:**

- Sync type: `full`
- Keep backups: `5` per branch type
- Release creation: `false` (unless `-r` flag used)

**Customization:**
Edit `scripts/manual-sync.sh` for custom behavior.

## Best Practices

### Sync Frequency

- **Weekly**: Automated sync for regular updates
- **Before major work**: Manual sync before starting new features
- **After upstream releases**: Sync after google-gemini releases

### Branch Management

- Keep feature branch focused on OpenRouter changes
- Use backup branches for safety, not long-term storage
- Regularly clean up merged branches

### Testing

- Always run tests after sync
- Test OpenRouter functionality specifically
- Monitor for breaking changes in upstream

### Documentation

- Update this document when making changes
- Document any custom merge strategies
- Keep track of known conflict patterns

## Support

### Getting Help

1. Check GitHub Actions logs for detailed error messages
2. Review conflict resolution instructions in created issues
3. Use dry-run mode to test before actual sync
4. Check backup branches for rollback options

### Reporting Issues

- Create issues for sync-related problems
- Include full error logs and timestamps
- Mention which branches were being synced
- Tag with `sync-automation` label

---

## Quick Reference

```bash
# Quick sync commands
./scripts/manual-sync.sh              # Full sync
./scripts/manual-sync.sh -t main-only # Main only
./scripts/manual-sync.sh -d          # Dry run
./scripts/manual-sync.sh -r          # With release

# Check status
git branch -r | grep backup/         # List backups
git log --oneline --grep="sync" -5   # Recent syncs
```

This automation system ensures your OpenRouter fork stays current while protecting your custom implementation! 🚀
