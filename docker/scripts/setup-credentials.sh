#!/bin/bash
# setup-credentials.sh - First-time credential setup helper
# Run this once after creating a new workspace

set -e

echo "=== Development Container Credential Setup ==="
echo ""

# Git configuration
echo "--- Git Configuration ---"
read -p "Enter your Git name: " git_name
read -p "Enter your Git email: " git_email

git config --global user.name "$git_name"
git config --global user.email "$git_email"

echo "Git configured successfully."
echo ""

# GitHub CLI login
echo "--- GitHub CLI Setup ---"
echo "Logging into GitHub CLI..."
gh auth login

echo ""

# Claude Code setup
echo "--- Claude Code Setup ---"
echo "To configure Claude Code with your API key, run:"
echo "  claude config set apiKey <your-api-key>"
echo ""
echo "Or login interactively:"
echo "  claude login"
echo ""

# SSH Key generation (optional)
echo "--- SSH Key Setup ---"
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    read -p "Generate a new SSH key? (y/n): " gen_ssh
    if [ "$gen_ssh" = "y" ]; then
        ssh-keygen -t ed25519 -C "$git_email" -f "$HOME/.ssh/id_ed25519" -N ""
        echo ""
        echo "Your SSH public key (add to GitHub/GitLab):"
        cat "$HOME/.ssh/id_ed25519.pub"
        echo ""
        echo "Or add it directly to GitHub:"
        echo "  gh ssh-key add ~/.ssh/id_ed25519.pub --title 'CloudWorkstation'"
    fi
else
    echo "SSH key already exists at $HOME/.ssh/id_ed25519"
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Your credentials are stored in:"
echo "  - Git config: ~/.gitconfig"
echo "  - GitHub CLI: ~/.config/gh/"
echo "  - Claude Code: ~/.claude/"
echo "  - SSH keys: ~/.ssh/"
echo ""
echo "These will persist across workspace restarts."
