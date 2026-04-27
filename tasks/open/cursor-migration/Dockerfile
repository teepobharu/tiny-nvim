# Neovim AI Development Container
# Extends your existing config with AI CLI tools
#
# Build: docker build -t nvim-ai .
# Run:   docker compose run --rm nvim

ARG BASE_IMAGE=ubuntu:24.04
FROM ${BASE_IMAGE}

LABEL maintainer="nvim-ai-container"
LABEL description="Neovim with AI development tools"

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm-256color
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# =============================================================================
# System Dependencies
# =============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core tools
    curl \
    wget \
    git \
    ca-certificates \
    gnupg \
    unzip \
    xclip \
    xsel \
    # Build tools (for Neovim plugins)
    build-essential \
    cmake \
    pkg-config \
    # Neovim dependencies
    ninja-build \
    gettext \
    # Language runtimes
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    # Shell
    zsh \
    tmux \
    fzf \
    ripgrep \
    fd-find \
    bat \
    # For clipboard over SSH
    socat \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Install Latest Neovim
# =============================================================================
ARG NVIM_VERSION=stable
RUN curl -LO "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux64.tar.gz" \
    && tar -xzf nvim-linux64.tar.gz \
    && mv nvim-linux64 /opt/nvim \
    && ln -s /opt/nvim/bin/nvim /usr/local/bin/nvim \
    && rm nvim-linux64.tar.gz

# =============================================================================
# Install Rust (for some tools)
# =============================================================================
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# =============================================================================
# Install Go (for some AI tools)
# =============================================================================
ARG GO_VERSION=1.22.0
RUN curl -LO "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" \
    && tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz \
    && rm go${GO_VERSION}.linux-amd64.tar.gz
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH="/root/go"
ENV PATH="${GOPATH}/bin:${PATH}"

# =============================================================================
# AI CLI Tools
# =============================================================================

# Node.js global packages
RUN npm install -g \
    # MCP servers
    @anthropics/mcp-hub \
    @modelcontextprotocol/server-filesystem \
    @modelcontextprotocol/server-git \
    @modelcontextprotocol/server-github \
    @modelcontextprotocol/server-memory \
    @modelcontextprotocol/server-fetch \
    # Cursor ACP bridge
    @blowmage/cursor-agent-acp \
    # Tree-sitter CLI
    tree-sitter-cli

# Goose AI Agent (Block's open-source agent)
RUN curl -fsSL https://github.com/block/goose/releases/latest/download/goose-linux-amd64 -o /usr/local/bin/goose \
    && chmod +x /usr/local/bin/goose

# Claude Code CLI (if available)
# Note: Requires authentication after container start
RUN npm install -g @anthropic-ai/claude-code || true

# Aider (AI pair programming)
RUN pip3 install --break-system-packages aider-chat

# =============================================================================
# Shell Configuration
# =============================================================================
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
    && git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions \
    && git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# =============================================================================
# Create directories
# =============================================================================
RUN mkdir -p \
    /root/.config/nvim \
    /root/.local/share/nvim \
    /root/.local/state/nvim \
    /root/.cache/nvim \
    /root/.config/goose \
    /root/.local/share/goose \
    /workspace

# =============================================================================
# Environment
# =============================================================================
ENV NVIM_APPNAME=nvim3_jelly_tinynvim
ENV XDG_CONFIG_HOME=/root/.config
ENV XDG_DATA_HOME=/root/.local/share
ENV XDG_STATE_HOME=/root/.local/state
ENV XDG_CACHE_HOME=/root/.cache

# Working directory
WORKDIR /workspace

# =============================================================================
# Entrypoint
# =============================================================================
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["nvim"]
