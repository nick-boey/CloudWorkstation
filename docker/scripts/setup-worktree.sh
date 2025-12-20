#!/bin/bash
# setup-worktree.sh - Helper script for managing git worktrees
# Usage: setup-worktree.sh <repo-url> [branch-name]

set -e

REPOS_DIR="${HOME}/repos"

show_help() {
    cat << EOF
Git Worktree Setup Helper

Usage:
    setup-worktree.sh <repo-url> [branch-name]
    setup-worktree.sh --list
    setup-worktree.sh --add <repo-name> <branch-name>
    setup-worktree.sh --remove <repo-name> <branch-name>

Commands:
    <repo-url>              Clone a repository as bare and create main worktree
    --list                  List all repositories and their worktrees
    --add <repo> <branch>   Add a new worktree for an existing repository
    --remove <repo> <branch> Remove a worktree

Examples:
    # Clone a new repository
    setup-worktree.sh https://github.com/user/myrepo.git

    # Clone and create a specific branch worktree
    setup-worktree.sh https://github.com/user/myrepo.git feature-branch

    # List all worktrees
    setup-worktree.sh --list

    # Add a new worktree for an existing repo
    setup-worktree.sh --add myrepo feature-new-api

    # Remove a worktree
    setup-worktree.sh --remove myrepo feature-new-api

EOF
}

list_worktrees() {
    echo "=== Git Worktrees ==="
    echo ""

    for bare_repo in "$REPOS_DIR"/*.git; do
        if [ -d "$bare_repo" ]; then
            repo_name=$(basename "$bare_repo" .git)
            echo "Repository: $repo_name"
            echo "Bare repo: $bare_repo"
            echo "Worktrees:"
            cd "$bare_repo"
            git worktree list | sed 's/^/  /'
            echo ""
        fi
    done
}

add_worktree() {
    local repo_name="$1"
    local branch_name="$2"
    local bare_repo="$REPOS_DIR/$repo_name.git"
    local worktree_path="$REPOS_DIR/$repo_name/$branch_name"

    if [ ! -d "$bare_repo" ]; then
        echo "Error: Repository '$repo_name' not found at $bare_repo"
        exit 1
    fi

    if [ -d "$worktree_path" ]; then
        echo "Error: Worktree '$branch_name' already exists at $worktree_path"
        exit 1
    fi

    cd "$bare_repo"

    # Check if branch exists remotely
    if git ls-remote --heads origin "$branch_name" | grep -q "$branch_name"; then
        echo "Creating worktree from existing remote branch: $branch_name"
        git fetch origin "$branch_name"
        git worktree add "$worktree_path" "$branch_name"
    else
        echo "Creating new branch and worktree: $branch_name"
        git worktree add -b "$branch_name" "$worktree_path" HEAD
    fi

    echo "Worktree created at: $worktree_path"
}

remove_worktree() {
    local repo_name="$1"
    local branch_name="$2"
    local bare_repo="$REPOS_DIR/$repo_name.git"
    local worktree_path="$REPOS_DIR/$repo_name/$branch_name"

    if [ ! -d "$bare_repo" ]; then
        echo "Error: Repository '$repo_name' not found"
        exit 1
    fi

    cd "$bare_repo"

    if [ -d "$worktree_path" ]; then
        git worktree remove "$worktree_path"
        echo "Worktree removed: $worktree_path"
    else
        echo "Error: Worktree not found at $worktree_path"
        exit 1
    fi
}

clone_repo() {
    local repo_url="$1"
    local branch_name="${2:-main}"

    # Extract repo name from URL
    local repo_name=$(basename "$repo_url" .git)
    local bare_repo="$REPOS_DIR/$repo_name.git"
    local worktree_path="$REPOS_DIR/$repo_name/$branch_name"

    mkdir -p "$REPOS_DIR"

    if [ -d "$bare_repo" ]; then
        echo "Repository already exists at $bare_repo"
        echo "Use --add to create additional worktrees"
        exit 1
    fi

    echo "Cloning $repo_url as bare repository..."
    git clone --bare "$repo_url" "$bare_repo"

    cd "$bare_repo"

    # Configure fetch to get all branches
    git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
    git fetch origin

    # Determine default branch
    local default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")

    # Create the initial worktree
    if [ "$branch_name" = "main" ] || [ "$branch_name" = "$default_branch" ]; then
        git worktree add "$worktree_path" "$default_branch"
    else
        # Check if specified branch exists
        if git ls-remote --heads origin "$branch_name" | grep -q "$branch_name"; then
            git worktree add "$worktree_path" "$branch_name"
        else
            git worktree add -b "$branch_name" "$worktree_path" "$default_branch"
        fi
    fi

    echo ""
    echo "=== Setup Complete ==="
    echo "Bare repository: $bare_repo"
    echo "Worktree: $worktree_path"
    echo ""
    echo "To create additional worktrees:"
    echo "  setup-worktree.sh --add $repo_name <branch-name>"
}

# Main
case "${1:-}" in
    -h|--help)
        show_help
        ;;
    --list)
        list_worktrees
        ;;
    --add)
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Error: --add requires <repo-name> and <branch-name>"
            exit 1
        fi
        add_worktree "$2" "$3"
        ;;
    --remove)
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Error: --remove requires <repo-name> and <branch-name>"
            exit 1
        fi
        remove_worktree "$2" "$3"
        ;;
    "")
        show_help
        ;;
    *)
        clone_repo "$1" "${2:-main}"
        ;;
esac
