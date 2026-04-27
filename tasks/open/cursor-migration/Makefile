# Neovim AI Container - Makefile
# ================================
# Quick commands for container management

.PHONY: help build run run-full run-minimal run-cursor run-gpu shell goose clean

# Default target
help:
	@echo "Neovim AI Container Commands"
	@echo "============================"
	@echo ""
	@echo "Build:"
	@echo "  make build          Build the container image"
	@echo "  make build-fresh    Build without cache"
	@echo ""
	@echo "Run Profiles:"
	@echo "  make run            Standard profile (avante + codecompanion)"
	@echo "  make run-full       Full profile (all AI tools + MCP Hub)"
	@echo "  make run-minimal    Minimal profile (base config only)"
	@echo "  make run-cursor     Cursor profile (Cursor CLI focus)"
	@echo "  make run-gpu        With local LLMs (Ollama + GPU)"
	@echo ""
	@echo "Tools:"
	@echo "  make goose          Run Goose AI agent"
	@echo "  make aider          Run Aider pair programming"
	@echo "  make shell          Open shell in container"
	@echo "  make mcp            Start MCP Hub server"
	@echo ""
	@echo "Maintenance:"
	@echo "  make logs           View container logs"
	@echo "  make clean          Remove containers and volumes"
	@echo "  make clean-all      Remove everything including images"
	@echo ""
	@echo "SSH Agent (for git operations):"
	@echo "  make run-ssh        Run with SSH agent forwarding"

# =============================================================================
# Build
# =============================================================================
build:
	docker compose build nvim

build-fresh:
	docker compose build --no-cache nvim

# =============================================================================
# Run Profiles
# =============================================================================
run:
	docker compose run --rm nvim

run-full:
	docker compose run --rm nvim-full

run-minimal:
	docker compose run --rm nvim-minimal

run-cursor:
	docker compose run --rm nvim-cursor

run-gpu:
	docker compose --profile gpu up -d ollama
	@echo "Waiting for Ollama to start..."
	@sleep 5
	docker compose --profile gpu run --rm nvim-local

# With SSH agent forwarding
run-ssh:
	docker compose run --rm \
		-e SSH_AUTH_SOCK=/ssh-agent \
		-v $(SSH_AUTH_SOCK):/ssh-agent \
		nvim

# =============================================================================
# Tools
# =============================================================================
goose:
	docker compose run --rm goose

aider:
	docker compose --profile dev run --rm aider

shell:
	docker compose run --rm nvim /bin/zsh

mcp:
	docker compose up -d mcp-hub
	@echo "MCP Hub started on http://localhost:5555"

# =============================================================================
# Maintenance
# =============================================================================
logs:
	docker compose logs -f

stop:
	docker compose down

clean:
	docker compose down -v

clean-all:
	docker compose down -v --rmi all

# =============================================================================
# Utility
# =============================================================================
# Pull models for local LLM
pull-models:
	docker compose --profile gpu up -d ollama
	docker exec ollama ollama pull codellama:7b
	docker exec ollama ollama pull deepseek-coder:6.7b
	@echo "Models pulled successfully"

# Check status
status:
	@echo "=== Containers ==="
	docker compose ps
	@echo ""
	@echo "=== Volumes ==="
	docker volume ls | grep -E "nvim|goose|mcp|ollama"
	@echo ""
	@echo "=== Networks ==="
	docker network ls | grep nvim-ai
