#!/bin/bash
# Neovim AI Container Entrypoint
# Handles plugin overlay and initialization

set -e

# =============================================================================
# Plugin Overlay System
# =============================================================================
# Merges extra plugins from /nvim-overlay into the config
OVERLAY_DIR="/nvim-overlay"
NVIM_CONFIG="/root/.config/nvim"

if [ -d "$OVERLAY_DIR/lua/plugins" ]; then
    echo "📦 Applying plugin overlay..."

    # Create extras directory if it doesn't exist
    mkdir -p "$NVIM_CONFIG/lua/plugins/extra"

    # Copy overlay plugins (won't overwrite existing)
    for file in "$OVERLAY_DIR/lua/plugins"/*.lua; do
        if [ -f "$file" ]; then
            basename=$(basename "$file")
            target="$NVIM_CONFIG/lua/plugins/extra/$basename"
            if [ ! -f "$target" ]; then
                cp "$file" "$target"
                echo "  ✓ Added: $basename"
            fi
        fi
    done
fi

# =============================================================================
# Profile-based Configuration
# =============================================================================
# NVIM_AI_PROFILE: minimal | standard | full | cursor
PROFILE="${NVIM_AI_PROFILE:-standard}"

case "$PROFILE" in
    minimal)
        echo "🔧 Profile: minimal (base config only)"
        # Remove AI overlay plugins
        rm -f "$NVIM_CONFIG/lua/plugins/extra/goose.lua" 2>/dev/null || true
        rm -f "$NVIM_CONFIG/lua/plugins/extra/agentic.lua" 2>/dev/null || true
        rm -f "$NVIM_CONFIG/lua/plugins/extra/cursor-agent.lua" 2>/dev/null || true
        ;;
    standard)
        echo "🔧 Profile: standard (avante + codecompanion)"
        # Keep existing AI plugins
        ;;
    full)
        echo "🔧 Profile: full (all AI tools)"
        # Enable all overlay plugins
        if [ -d "$OVERLAY_DIR" ]; then
            cp -n "$OVERLAY_DIR/lua/plugins"/*.lua "$NVIM_CONFIG/lua/plugins/extra/" 2>/dev/null || true
        fi
        ;;
    cursor)
        echo "🔧 Profile: cursor (Cursor CLI focus)"
        # Only enable cursor-related plugins
        cp -n "$OVERLAY_DIR/lua/plugins/cursor-agent.lua" "$NVIM_CONFIG/lua/plugins/extra/" 2>/dev/null || true
        cp -n "$OVERLAY_DIR/lua/plugins/agentic.lua" "$NVIM_CONFIG/lua/plugins/extra/" 2>/dev/null || true
        ;;
esac

# =============================================================================
# MCP Hub Startup (if enabled)
# =============================================================================
if [ "$ENABLE_MCP_HUB" = "true" ]; then
    echo "🔌 Starting MCP Hub on port ${MCP_PORT:-5555}..."
    mcp-hub --port "${MCP_PORT:-5555}" --config /root/.config/mcp/servers.json &
    sleep 2
fi

# =============================================================================
# Goose Session Restoration
# =============================================================================
if [ -d "/root/.local/share/goose/sessions" ] && [ "$RESTORE_GOOSE_SESSION" = "true" ]; then
    echo "📝 Goose sessions available for restoration"
fi

# =============================================================================
# Git Configuration (from host)
# =============================================================================
if [ -f "/host-gitconfig" ]; then
    cp /host-gitconfig /root/.gitconfig
    echo "🔧 Git config loaded from host"
fi

# =============================================================================
# SSH Agent Forwarding
# =============================================================================
if [ -n "$SSH_AUTH_SOCK" ]; then
    echo "🔑 SSH agent available"
fi

# =============================================================================
# First-run Plugin Installation
# =============================================================================
if [ ! -d "/root/.local/share/nvim/lazy" ]; then
    echo "📥 First run: Installing plugins..."
    nvim --headless "+Lazy! sync" +qa 2>/dev/null || true
    echo "✅ Plugins installed"
fi

# =============================================================================
# Execute Command
# =============================================================================
echo "🚀 Starting: $@"
exec "$@"
