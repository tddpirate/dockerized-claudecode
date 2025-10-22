# dockerized-claudecode - Claude Code Docker Setup

A secure Docker environment for running Claude Code on your projects with filesystem isolation.

## 📋 Prerequisites

- Docker and Docker Compose installed
- A project directory you want to work on
- Anthropic API key OR Claude Pro/Max subscription

## 🚀 Quick Start

### Method 1: Automated Setup (Recommended)

1. Make the setup script executable:
```bash
chmod +x setup-and-run.sh
```

2. Run the setup script:
```bash
./setup-and-run.sh
```

The script will:
- ✅ Prompt you for your project directory
- ✅ Validate the directory exists
- ✅ Create the `.env` configuration file
- ✅ Optionally save your API key
- ✅ Build the Docker image
- ✅ Start the container
- ✅ Drop you into an interactive shell

3. Inside the container, start Claude Code:
```bash
claude
```

### Method 2: Manual Setup

1. Create a `.env` file:
```bash
PROJECT_DIR=/absolute/path/to/your/project
ANTHROPIC_API_KEY=your-api-key-here
ANTHROPIC_MODEL=claude-sonnet-4-5-20250929
```

2. Build and start the container:
```bash
docker-compose build
docker-compose up -d
docker-compose exec claude-code bash
```

3. Inside the container, run Claude Code:
```bash
claude
```

## 🔐 Security Features

### Filesystem Isolation
- Your project is mounted at `/workspace` inside the container
- Claude Code **cannot** access files outside this directory on your host
- Host system files (like `~/.ssh`, `~/.aws`) are **not** accessible
- Perfect for working on untrusted or experimental code

### Resource Limits
The container is configured with:
- CPU limit: 2 cores
- Memory limit: 4GB
- Memory reservation: 1GB

Adjust these in `docker-compose.yml` as needed.

### Network Isolation (Optional)
To completely disable network access (maximum security):
```yaml
# In docker-compose.yml, uncomment:
network_mode: none
```

**Note:** This will prevent Claude Code from accessing the Anthropic API. Use only for offline testing.

## 🛠️ Container Management

### Start the container
```bash
docker-compose start
docker-compose exec claude-code bash
```

### Stop the container
```bash
docker-compose down
```

### View logs
```bash
docker-compose logs -f
```

### Restart the container
```bash
docker-compose restart
```

### Rebuild after changes
```bash
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

## 📁 Working with Multiple Projects

To switch to a different project:

1. Stop the current container:
```bash
docker-compose down
```

2. Update the `.env` file with the new project path:
```bash
PROJECT_DIR=/path/to/different/project
```

3. Start the container again:
```bash
docker-compose up -d
docker-compose exec claude-code bash
```

**Alternative:** Run the setup script again to interactively choose a new project.

## ⚙️ Configuration

### Environment Variables (.env file)

- **PROJECT_DIR**: Absolute path to your project directory (required)
- **ANTHROPIC_API_KEY**: Your Anthropic API key (optional if using OAuth)
- **ANTHROPIC_MODEL**: Claude model to use (default: claude-sonnet-4-5-20250929)

### Claude Code Settings

Settings are persisted in a Docker volume (`claude-settings`). To configure permissions:

1. Inside the container, create `~/.claude/settings.json`:
```json
{
  "permissions": {
    "deny": [
      "Read(./.env)",
      "Read(./.env.*)",
      "Read(./secrets/**)"
    ],
    "ask": [
      "Bash(git push:*)",
      "Bash(docker:*)"
    ]
  }
}
```

2. Or use the interactive command:
```bash
claude
/permissions
```

## 🔧 Authentication

### Option 1: OAuth (Recommended)
1. Run `claude` in the container
2. Follow the OAuth flow in your browser
3. Choose Claude Pro/Max subscription or API

### Option 2: API Key
Set `ANTHROPIC_API_KEY` in your `.env` file before starting the container.

## 📦 What's Installed

The container includes:
- Node.js 20 (Alpine Linux)
- Claude Code CLI (latest version)
- Git
- Python 3
- Common development tools (bash, curl, vim, nano)
- SSH client
- Build tools (gcc, make, etc.)

## 🐛 Troubleshooting

### "Project directory not found"
Ensure you're using the **absolute path** to your project:
```bash
# Good
PROJECT_DIR=/home/username/projects/myapp

# Bad (relative paths don't work)
PROJECT_DIR=./myapp
PROJECT_DIR=~/projects/myapp
```

### "Permission denied" accessing files
The container runs as root by default. If you encounter permission issues:
```bash
# On host, make files readable
chmod -R a+r /path/to/project

# For write access
chmod -R a+rw /path/to/project
```

### Container won't start
```bash
# Check logs
docker-compose logs

# Rebuild from scratch
docker-compose down -v
docker-compose build --no-cache
docker-compose up -d
```

### Claude Code authentication fails
1. Ensure you have internet access (unless using `network_mode: none`)
2. Try setting the API key in `.env` instead of OAuth
3. Check your API key is valid at https://console.anthropic.com/

## 🎯 Use Cases

### ✅ Safe for:
- Testing Claude Code on unfamiliar projects
- Working on open-source code
- Experimenting with AI-generated code
- Learning Claude Code features
- CI/CD pipelines (with `--dangerously-skip-permissions`)

### ⚠️ Consider alternatives for:
- Projects requiring access to host SSH keys
- Projects needing host environment variables
- Workflows requiring host Docker access
- Projects with database connections on host

## 📝 Best Practices

1. **Always use Git** in your project directory for easy rollback
2. **Review changes** before committing Claude Code's modifications
3. **Start with plan mode** to understand what Claude wants to do
4. **Set permission denials** for sensitive files in settings.json
5. **Limit resources** appropriately in docker-compose.yml
6. **Regular backups** of your project directory

## 🔗 Additional Resources

- [Claude Code Documentation](https://docs.claude.com/en/docs/claude-code)
- [Claude Code Settings](https://docs.claude.com/en/docs/claude-code/settings)
- [Claude Code Best Practices](https://www.anthropic.com/engineering/claude-code-best-practices)
- [Anthropic Console](https://console.anthropic.com/)

## 📄 License ![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)

The files in this repository are licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

This software is provided as-is for use with Claude Code, without any warranty. The author is not liable for any damages or issues arising from the use of this Docker setup. Use at your own risk. See Anthropic's terms of service for Claude Code usage.

For security best practices when using Claude Code, please review the [official documentation](https://docs.claude.com/en/docs/claude-code).
