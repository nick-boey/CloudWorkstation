#!/bin/bash
set -e

echo "Starting development container..."

# Ensure SSH directory has correct permissions
if [ -d "/home/vscode/.ssh" ]; then
    chmod 700 /home/vscode/.ssh
    if [ -f "/home/vscode/.ssh/authorized_keys" ]; then
        chmod 600 /home/vscode/.ssh/authorized_keys
    fi
fi

# Ensure config directories exist
mkdir -p /home/vscode/.config/gh
mkdir -p /home/vscode/.claude
mkdir -p /home/vscode/.happy
mkdir -p /home/vscode/.dotnet
mkdir -p /home/vscode/repos

# Clone repository if GIT_REPOSITORY is set
if [ -n "$GIT_REPOSITORY" ]; then
    REPO_NAME=$(basename "$GIT_REPOSITORY" .git)
    REPO_DIR="/home/vscode/repos/$REPO_NAME"

    if [ ! -d "$REPO_DIR" ]; then
        echo "Cloning repository: $GIT_REPOSITORY"
        git clone "$GIT_REPOSITORY" "$REPO_DIR"
        echo "Repository cloned to $REPO_DIR"
    else
        echo "Repository $REPO_NAME already exists at $REPO_DIR"
        cd "$REPO_DIR"
        git pull || echo "Could not pull latest changes (may need authentication)"
    fi

    # Change to repository directory
    cd "$REPO_DIR"
    echo "Working directory: $(pwd)"
fi

# Download and run Coder agent if token is provided
if [ -n "$CODER_AGENT_TOKEN" ]; then
    echo "Starting Coder agent..."

    # Download coder binary
    CODER_BINARY="/tmp/coder"
    if [ ! -f "$CODER_BINARY" ]; then
        curl -fsSL "${CODER_AGENT_URL}/bin/coder-linux-amd64" -o "$CODER_BINARY"
        chmod +x "$CODER_BINARY"
    fi

    # Start Happy CLI in background if repository was cloned
    if [ -n "$GIT_REPOSITORY" ] && command -v happy &> /dev/null; then
        echo "Starting Happy CLI for mobile connectivity..."

        REPO_NAME=$(basename "$GIT_REPOSITORY" .git)
        REPO_DIR="/home/vscode/repos/$REPO_NAME"

        # Start happy in the repository directory
        cd "$REPO_DIR"
        happy &
        HAPPY_PID=$!
        echo "Happy CLI started with PID $HAPPY_PID"
    fi

    # Start the agent (this will block and manage the container lifecycle)
    exec "$CODER_BINARY" agent
else
    echo "No Coder agent token found, starting in standalone mode..."

    # Start Happy CLI in background if repository was cloned
    if [ -n "$GIT_REPOSITORY" ] && command -v happy &> /dev/null; then
        echo "Starting Happy CLI for mobile connectivity..."

        REPO_NAME=$(basename "$GIT_REPOSITORY" .git)
        REPO_DIR="/home/vscode/repos/$REPO_NAME"

        cd "$REPO_DIR"
        happy &
        HAPPY_PID=$!
        echo "Happy CLI started with PID $HAPPY_PID"
    fi

    # Start SSH server if running standalone
    if [ -f "/usr/sbin/sshd" ]; then
        echo "Starting SSH server..."
        sudo /usr/sbin/sshd -D &
    fi

    # Keep container running
    exec tail -f /dev/null
fi
