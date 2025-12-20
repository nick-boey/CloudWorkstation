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
mkdir -p /home/vscode/.dotnet
mkdir -p /home/vscode/repos

# Download and run Coder agent if token is provided
if [ -n "$CODER_AGENT_TOKEN" ]; then
    echo "Starting Coder agent..."

    # Download coder binary
    CODER_BINARY="/tmp/coder"
    if [ ! -f "$CODER_BINARY" ]; then
        curl -fsSL "${CODER_AGENT_URL}/bin/coder-linux-amd64" -o "$CODER_BINARY"
        chmod +x "$CODER_BINARY"
    fi

    # Start the agent in the background
    exec "$CODER_BINARY" agent
else
    echo "No Coder agent token found, starting in standalone mode..."

    # Start SSH server if running standalone
    if [ -f "/usr/sbin/sshd" ]; then
        echo "Starting SSH server..."
        sudo /usr/sbin/sshd -D &
    fi

    # Keep container running
    exec tail -f /dev/null
fi
