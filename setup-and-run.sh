#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Claude Code Docker Setup${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Function to resolve absolute path
resolve_path() {
    if [[ "$1" = /* ]]; then
        # Already absolute path
        echo "$1"
    else
        # Relative path - make absolute
        echo "$(cd "$(dirname "$1")" 2>/dev/null && pwd)/$(basename "$1")"
    fi
}

# Get current user's UID and GID
CURRENT_UID=$(id -u)
CURRENT_GID=$(id -g)
CURRENT_USER=$(whoami)

echo -e "${GREEN}Detected host user: $CURRENT_USER (UID=$CURRENT_UID, GID=$CURRENT_GID)${NC}"
echo -e "${GREEN}Container will run as this user to preserve file ownership${NC}"
echo ""

# Prompt for project directory
echo -e "${YELLOW}Enter the full path to your project directory:${NC}"
read -e -p "Project path: " PROJECT_PATH

# Expand tilde if present
PROJECT_PATH="${PROJECT_PATH/#\~/$HOME}"

# Resolve to absolute path
PROJECT_PATH=$(resolve_path "$PROJECT_PATH")

# Validate directory exists
if [ ! -d "$PROJECT_PATH" ]; then
    echo -e "${RED}Error: Directory does not exist: $PROJECT_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Project directory found: $PROJECT_PATH${NC}"
echo ""

# Extract default project name from path (last directory component)
DEFAULT_PROJNAME=$(basename "$PROJECT_PATH")

# Prompt for project name (for Claude settings isolation)
echo -e "${YELLOW}Enter a project name for Claude Code settings isolation:${NC}"
echo -e "${YELLOW}This will store settings in /home/claudeuser/.claude/${NC}${GREEN}<projname>${NC}"
echo -e "${YELLOW}Project name must be a valid directory name (no spaces, slashes, etc.)${NC}"
read -e -p "Project name [${DEFAULT_PROJNAME}]: " PROJECT_NAME

# Use default if empty
if [ -z "$PROJECT_NAME" ]; then
    PROJECT_NAME="$DEFAULT_PROJNAME"
fi

# Validate project name (basic check for valid directory name)
if [[ ! "$PROJECT_NAME" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    echo -e "${RED}Error: Invalid project name. Use only letters, numbers, dots, hyphens, and underscores.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Project name: $PROJECT_NAME${NC}"
echo -e "${GREEN}✓ Claude settings will be stored in: /home/claudeuser/.claude/$PROJECT_NAME${NC}"
echo ""

# Check if .env file exists
if [ -f .env ]; then
    echo -e "${YELLOW}Found existing .env file. Backing it up to .env.backup${NC}"
    cp .env .env.backup
fi

# Create .env file with user IDs
cat > .env << EOF
# Project directory to mount in container
PROJECT_DIR=$PROJECT_PATH

# Project name for Claude settings isolation
# Settings stored in: /home/claudeuser/.claude/$PROJECT_NAME
PROJECT_NAME=$PROJECT_NAME

# Host user/group IDs (to preserve file ownership)
USER_ID=$CURRENT_UID
GROUP_ID=$CURRENT_GID
USERNAME=claudeuser

# Anthropic API Key (optional - leave empty to use OAuth during container session)
# Get your API key from: https://console.anthropic.com/
ANTHROPIC_API_KEY=

# Claude model to use (optional)
ANTHROPIC_MODEL=claude-sonnet-4-5-20250929
EOF

echo -e "${GREEN}✓ Created .env file with project configuration${NC}"
echo ""

# Prompt for API key (optional)
echo -e "${YELLOW}Do you want to set your Anthropic API key now? (optional)${NC}"
echo -e "${YELLOW}You can also authenticate via OAuth when you start Claude Code${NC}"
read -p "Set API key now? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Enter your Anthropic API key:${NC}"
    read -s API_KEY
    echo ""
    
    if [ ! -z "$API_KEY" ]; then
        # Update .env file with API key
        sed -i.bak "s/ANTHROPIC_API_KEY=$/ANTHROPIC_API_KEY=$API_KEY/" .env
        rm .env.bak 2>/dev/null || true
        echo -e "${GREEN}✓ API key saved to .env file${NC}"
    fi
fi

echo ""
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Building Docker image...${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Build the Docker image with user IDs
docker-compose build

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Docker build failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ Docker image built successfully${NC}"
echo ""
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Starting Claude Code container...${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Start the container
docker-compose up -d

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to start container${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Container started successfully${NC}"
echo ""

# Attach to container
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Entering container shell...${NC}"
echo -e "${BLUE}================================${NC}"
echo ""
echo -e "${YELLOW}Your project is mounted at: /workspace${NC}"
echo -e "${YELLOW}Container user: $CURRENT_USER (UID=$CURRENT_UID, GID=$CURRENT_GID)${NC}"
echo -e "${YELLOW}Files created will be owned by your host user!${NC}"
echo -e "${YELLOW}Claude settings: /home/claudeuser/.claude/$PROJECT_NAME${NC}"
echo ""
echo -e "${YELLOW}To start Claude Code, simply run: ${GREEN}claude${NC}"
echo ""
echo -e "${YELLOW}First-time setup:${NC}"
echo -e "  1. Run ${GREEN}claude${NC} in the container"
echo -e "  2. Authenticate via OAuth (browser will open)"
echo -e "  3. Start coding with Claude!"
echo ""
echo -e "${YELLOW}To exit the container: type ${GREEN}exit${NC} or press ${GREEN}Ctrl+D${NC}"
echo -e "${YELLOW}To stop the container: ${GREEN}docker-compose down${NC}"
echo -e "${YELLOW}To restart later: ${GREEN}docker-compose start && docker-compose exec claude-code bash${NC}"
echo ""
read -p "Press Enter to continue..."

# Attach to the container
docker-compose exec claude-code bash
