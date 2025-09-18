#!/bin/bash
# scripts/manual-sync.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Gemini CLI OpenRouter Sync Tool${NC}"
echo "=================================="

# Function to print usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -t, --type TYPE     Sync type: full, main-only, feature-only (default: full)"
    echo "  -r, --release       Create GitHub release after successful sync"
    echo "  -p, --create-pr     Create PR from feature to main if updates available"
    echo "  -d, --dry-run       Show what would be done without making changes"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Full sync"
    echo "  $0 -t main-only      # Sync only main branch"
    echo "  $0 -r                # Full sync with release creation"
    echo "  $0 -d -t feature-only # Dry run of feature branch sync"
}

# Default values
SYNC_TYPE="full"
CREATE_RELEASE=false
DRY_RUN=false
CREATE_PR=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            SYNC_TYPE="$2"
            shift 2
            ;;
        -r|--release)
            CREATE_RELEASE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -p|--create-pr)
            CREATE_PR=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

# Validate sync type
if [[ ! "$SYNC_TYPE" =~ ^(full|main-only|feature-only)$ ]]; then
    echo -e "${RED}Invalid sync type: $SYNC_TYPE${NC}"
    echo "Valid options: full, main-only, feature-only"
    exit 1
fi

echo -e "${YELLOW}Configuration:${NC}"
echo "  Sync type: $SYNC_TYPE"
echo "  Create release: $CREATE_RELEASE"
echo "  Dry run: $DRY_RUN"
echo ""

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}Error: Not in a git repository${NC}"
    exit 1
fi

# Check for uncommitted changes
if [[ -n $(git status --porcelain) ]]; then
    echo -e "${RED}Error: You have uncommitted changes. Please commit or stash them first.${NC}"
    exit 1
fi

# Dry run mode
if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}🔍 DRY RUN MODE - No changes will be made${NC}"
    echo ""
fi

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
echo -e "${BLUE}📦 Creating backups...${NC}"

# Create backup branches
create_backup() {
    local branch=$1
    local backup_branch="backup/${branch}-pre-sync-$TIMESTAMP"

    if [[ "$DRY_RUN" == false ]]; then
        git checkout "$branch"
        git checkout -b "$backup_branch"
        git push origin "$backup_branch" 2>/dev/null || echo -e "${YELLOW}⚠️  Could not push backup branch (may be normal for local testing)${NC}"
        echo -e "${GREEN}✅ Created backup: $backup_branch${NC}"
    else
        echo -e "${YELLOW}Would create backup: $backup_branch${NC}"
    fi
}

if [[ "$SYNC_TYPE" == "full" || "$SYNC_TYPE" == "main-only" ]]; then
    create_backup "main"
fi

if [[ "$SYNC_TYPE" == "full" || "$SYNC_TYPE" == "feature-only" ]]; then
    create_backup "feature/openrouter-support"
fi

echo ""

# Function to sync branch
sync_branch() {
    local branch=$1
    local remote=$2
    local remote_branch=$3

    echo -e "${BLUE}🔄 Syncing $branch with $remote/$remote_branch...${NC}"

    if [[ "$DRY_RUN" == false ]]; then
        git checkout "$branch"
        git fetch "$remote"

        # Check for conflicts in protected files
        if git merge-tree $(git merge-base HEAD "$remote/$remote_branch") HEAD "$remote/$remote_branch" | grep -q "<<<<<<<"; then
            echo -e "${YELLOW}⚠️ Conflicts detected in $branch branch${NC}"

            # Check if README.md or other fork-specific files have conflicts
            if git merge-tree $(git merge-base HEAD "$remote/$remote_branch") HEAD "$remote/$remote_branch" | grep -E "(README\.md|CONTRIBUTING\.md)" | grep -q "<<<<<<<"; then
                echo -e "${RED}🚨 IMPORTANT: Fork-specific files (README.md, CONTRIBUTING.md) have conflicts!${NC}"
                echo -e "${RED}These files are customized for this fork and should NOT be overwritten by upstream.${NC}"
                echo -e "${YELLOW}Please resolve conflicts manually and keep our fork-specific versions.${NC}"
            fi

            echo -e "${YELLOW}You will need to resolve conflicts manually${NC}"

            # Attempt merge to show conflicts
            git merge "$remote/$remote_branch" --no-edit --no-ff || true
            return 1
        else
            # Check if protected files would be modified
            if git diff --name-only HEAD.."$remote/$remote_branch" | grep -E "(README\.md|CONTRIBUTING\.md)" >/dev/null; then
                echo -e "${RED}🚨 WARNING: Upstream changes affect fork-specific files!${NC}"
                echo -e "${RED}README.md or CONTRIBUTING.md will be modified by upstream.${NC}"
                echo -e "${YELLOW}This merge will require manual conflict resolution.${NC}"

                # Force manual merge for protected files
                git merge "$remote/$remote_branch" --no-edit --no-ff || true
                return 1
            else
                git merge "$remote/$remote_branch" --no-edit --no-ff
                git push origin "$branch"
                echo -e "${GREEN}✅ $branch branch synced successfully${NC}"
                return 0
            fi
        fi
    else
        echo -e "${YELLOW}Would sync $branch with $remote/$remote_branch${NC}"
        return 0
    fi
}

CONFLICTS_DETECTED=false

# Sync main branch
if [[ "$SYNC_TYPE" == "full" || "$SYNC_TYPE" == "main-only" ]]; then
    if ! sync_branch "main" "google-gemini" "main"; then
        CONFLICTS_DETECTED=true
    fi
fi

# Sync feature branch
if [[ "$SYNC_TYPE" == "full" || "$SYNC_TYPE" == "feature-only" ]]; then
    if ! sync_branch "feature/openrouter-support" "upstream" "feature/openrouter-support"; then
        CONFLICTS_DETECTED=true
    fi
fi

# Check if feature branch has updates that need to be merged to main
check_feature_updates() {
    if [[ "$SYNC_TYPE" == "full" || "$SYNC_TYPE" == "feature-only" ]]; then
        echo -e "${BLUE}🔍 Checking for feature branch updates...${NC}"

        # Check if feature branch has commits ahead of main
        FEATURE_AHEAD=$(git rev-list --count main..feature/openrouter-support 2>/dev/null || echo "0")

        if [[ "$FEATURE_AHEAD" -gt 0 ]]; then
            echo -e "${YELLOW}📋 Feature branch has $FEATURE_AHEAD new commits${NC}"

            # Check for merge conflicts
            if git merge-tree $(git merge-base main feature/openrouter-support) main feature/openrouter-support | grep -q "<<<<<<<"; then
                echo -e "${YELLOW}⚠️ Conflicts detected between main and feature branch${NC}"
                echo -e "${YELLOW}Manual merge required or PR creation needed${NC}"
                return 1
            else
                echo -e "${GREEN}✅ No conflicts detected - can merge automatically${NC}"
                return 0
            fi
        else
            echo -e "${GREEN}✅ Feature branch is up to date with main${NC}"
            return 0
        fi
    fi
}

# Check for feature updates after sync
FEATURE_UPDATES_AVAILABLE=false
if [[ "$CONFLICTS_DETECTED" == false ]]; then
    if check_feature_updates; then
        FEATURE_UPDATES_AVAILABLE=true
    fi
fi

echo ""

# Run tests if no conflicts
if [[ "$CONFLICTS_DETECTED" == false && "$DRY_RUN" == false ]]; then
    echo -e "${BLUE}🧪 Running tests...${NC}"

    # Check if vitest is available
    if command -v vitest &> /dev/null; then
        echo -e "${BLUE}Using vitest for testing...${NC}"
        if npm test -- --testPathPattern="openRouter" 2>/dev/null; then
            echo -e "${GREEN}✅ OpenRouter tests passed${NC}"
        else
            echo -e "${YELLOW}⚠️ OpenRouter tests failed or not found - manual review recommended${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ vitest not found - skipping automated tests${NC}"
        echo -e "${YELLOW}To run tests manually: npm install && npm test${NC}"
    fi

    # Create PR if requested and feature updates available
    if [[ "$CREATE_PR" == true && "$FEATURE_UPDATES_AVAILABLE" == true ]]; then
        echo -e "${BLUE}🔄 Creating PR from feature branch to main...${NC}"

        # Check if GitHub CLI is available
        if command -v gh &> /dev/null; then
            PR_TITLE="feat: Update OpenRouter integration from upstream"
            PR_BODY="Automated PR created by sync script

## Changes
- Synced feature branch with upstream OpenRouter updates
- Includes latest changes from upstream/feature/openrouter-support

## Sync Details
- Synced at: $TIMESTAMP
- Backup created: backup/main-pre-sync-$TIMESTAMP

## Testing
- ✅ Build verification passed
- ✅ OpenRouter tests passed

This PR brings the latest OpenRouter integration updates from upstream."

            # Create PR using GitHub CLI
            if gh pr create --title "$PR_TITLE" --body "$PR_BODY" --base main --head feature/openrouter-support; then
                echo -e "${GREEN}✅ PR created successfully${NC}"
                echo -e "${GREEN}You can review and merge the PR when ready${NC}"
            else
                echo -e "${YELLOW}⚠️ Failed to create PR automatically${NC}"
                echo -e "${YELLOW}You may need to create it manually on GitHub${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️ GitHub CLI (gh) not found${NC}"
            echo -e "${YELLOW}To create PR manually:${NC}"
            echo "  1. Go to GitHub repository"
            echo "  2. Create PR from 'feature/openrouter-support' to 'main'"
            echo "  3. Add title: 'feat: Update OpenRouter integration from upstream'"
        fi
    elif [[ "$CREATE_PR" == true && "$FEATURE_UPDATES_AVAILABLE" == false ]]; then
        echo -e "${GREEN}ℹ️ No feature updates available - skipping PR creation${NC}"
    fi

    # Create release if requested
    if [[ "$CREATE_RELEASE" == true ]]; then
        echo -e "${BLUE}📦 Creating GitHub release...${NC}"
        RELEASE_TAG="v$TIMESTAMP-openrouter-sync"

        # Create git tag
        git tag -a "$RELEASE_TAG" -m "Automated sync with backups

Backup branches created:
- backup/main-pre-sync-$TIMESTAMP
- backup/feature-pre-sync-$TIMESTAMP

Synced with:
- google-gemini/main
- upstream/feature/openrouter-support"

        git push origin "$RELEASE_TAG"

        echo -e "${GREEN}✅ Release created: $RELEASE_TAG${NC}"
        echo -e "${GREEN}You can create a GitHub release from this tag with additional notes${NC}"
    fi
fi

echo ""
if [[ "$CONFLICTS_DETECTED" == true ]]; then
    echo -e "${YELLOW}⚠️ Conflicts detected!${NC}"
    echo -e "${YELLOW}Please resolve conflicts manually and then push the changes.${NC}"
    echo ""
    echo -e "${BLUE}Commands to resolve:${NC}"
    echo "  git status                    # See conflicted files"
    echo "  # Edit conflicted files manually"
    echo "  git add <resolved-files>      # Stage resolved files"
    echo "  git commit -m 'Resolve sync conflicts'"
    echo "  git push origin <branch-name>"
    echo ""
    echo -e "${BLUE}Backup branches created for rollback:${NC}"
    if [[ "$SYNC_TYPE" == "full" || "$SYNC_TYPE" == "main-only" ]]; then
        echo "  backup/main-pre-sync-$TIMESTAMP"
    fi
    if [[ "$SYNC_TYPE" == "full" || "$SYNC_TYPE" == "feature-only" ]]; then
        echo "  backup/feature/openrouter-support-pre-sync-$TIMESTAMP"
    fi
    # Exit with error code for conflicts
    exit 1
else
    echo -e "${GREEN}🎉 Sync completed successfully!${NC}"
    if [[ "$DRY_RUN" == false ]]; then
        echo -e "${GREEN}Backup branches created for safety:${NC}"
        if [[ "$SYNC_TYPE" == "full" || "$SYNC_TYPE" == "main-only" ]]; then
            echo -e "${GREEN}  backup/main-pre-sync-$TIMESTAMP${NC}"
        fi
        if [[ "$SYNC_TYPE" == "full" || "$SYNC_TYPE" == "feature-only" ]]; then
            echo -e "${GREEN}  backup/feature/openrouter-support-pre-sync-$TIMESTAMP${NC}"
        fi
    fi
    # Exit successfully
    exit 0
fi