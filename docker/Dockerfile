# Base image: Microsoft .NET Dev Container (Debian-based)
ARG DOTNET_VERSION=9.0
FROM mcr.microsoft.com/devcontainers/dotnet:1-${DOTNET_VERSION}

# Arguments for customization
ARG NODE_VERSION="20"
ARG CLAUDE_CODE_VERSION="latest"
ARG HAPPY_CLI_VERSION="latest"

# Labels
LABEL maintainer="CloudWorkstation"
LABEL description="Development container with .NET, Claude Code, Happy CLI, and GitHub CLI"

# Switch to root for installations
USER root

# Install system dependencies
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends \
        openssh-server \
        curl \
        wget \
        jq \
        unzip \
        htop \
        tmux \
        vim \
        nano \
        tree \
        less \
        procps \
        ca-certificates \
        gnupg \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configure SSH server
RUN mkdir -p /var/run/sshd \
    && sed -i 's/#PermitUserEnvironment no/PermitUserEnvironment yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Install Node.js (required for Claude Code CLI and Happy CLI)
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code CLI globally
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

# Install Happy CLI globally (for mobile Claude Code connectivity)
RUN npm install -g happy-coder@${HAPPY_CLI_VERSION}

# Create directories for persistent data
RUN mkdir -p /home/vscode/.ssh \
    && mkdir -p /home/vscode/.config/gh \
    && mkdir -p /home/vscode/.local/share \
    && mkdir -p /home/vscode/repos \
    && mkdir -p /home/vscode/.claude \
    && mkdir -p /home/vscode/.happy \
    && mkdir -p /home/vscode/.dotnet

# Copy setup scripts
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/setup-worktree.sh /usr/local/bin/setup-worktree.sh
COPY scripts/setup-credentials.sh /usr/local/bin/setup-credentials.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/setup-worktree.sh /usr/local/bin/setup-credentials.sh

# Set ownership for vscode user
RUN chown -R vscode:vscode /home/vscode

# Switch back to vscode user
USER vscode

# Configure git defaults
RUN git config --global init.defaultBranch main \
    && git config --global core.autocrlf input \
    && git config --global pull.rebase true \
    && git config --global fetch.prune true \
    && git config --global diff.colorMoved zebra

# Set working directory
WORKDIR /home/vscode

# Environment variables for persistent credentials and Happy CLI
ENV HOME=/home/vscode
ENV GH_CONFIG_DIR=/home/vscode/.config/gh
ENV CLAUDE_CONFIG_DIR=/home/vscode/.claude
ENV HAPPY_HOME_DIR=/home/vscode/.happy
ENV DOTNET_CLI_HOME=/home/vscode/.dotnet
ENV DOTNET_NOLOGO=true

# Happy Server URL will be injected at runtime via HAPPY_SERVER_URL env var

# Expose SSH port
EXPOSE 22

# Entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
