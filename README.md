# Claude Code Docker Setup

A secure Docker environment for running Claude Code on your projects with filesystem isolation and proper file ownership.

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
- ✅ Detect your host user ID (UID) and group ID (GID) automatically
- ✅ Prompt you for your project directory
- ✅ Prompt you for a project name (for settings isolation)
- ✅ Validate the directory exists and project name is valid
- ✅ Create the `.env` configuration file with your user IDs and project name
- ✅ Optionally save your API key
- ✅ Build the Docker image with matching user/group
- ✅ Start the container with isolated Claude settings
- ✅ Drop you into an interactive shell

3. Inside the container, start Claude Code:
```bash
claude
```

### Method 2: Manual Setup

1. Create a `.env` file:
```bash
PROJECT_DIR=/absolute/path/to/your/project
PROJECT_NAME=myproject
USER_ID=1000
GROUP_ID=1000
USERNAME=node
ANTHROPIC_API_KEY=your-api-key-here
ANTHROPIC_MODEL=claude-sonnet-4-5-20250929
```

**Important:** Get your actual user IDs and choose a project name:
```bash
id -u  # Your USER_ID
id -g  # Your GROUP_ID
basename /path/to/your/project  # Suggested PROJECT_NAME
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

### Per-Project Settings Isolation
- **Shared OAuth credentials**: Authenticate once via `claude-credentials` volume, use across all projects
- **Per-project settings**: Each project gets its own `claude-settings-${PROJECT_NAME}` volume
- Settings stored in: `/home/node/.claude/` (different volume per project)
- Credentials symlinked from: `/home/node/.claude-shared/.credentials.json`
- Different projects can use different Claude accounts or API keys
- Prevents configuration conflicts between projects
- Easy to reset settings for a specific project without affecting others

**Example:**
```bash
# Project A uses OAuth with Claude Pro
PROJECT_NAME=projectA
# Volume: claude-settings-projectA
# Credentials: Shared via claude-credentials volume

# Project B uses API key
PROJECT_NAME=projectB
# Volume: claude-settings-projectB
# Credentials: Shared via claude-credentials volume

# Each project gets its own volume but shares OAuth credentials
```

### File Ownership Preservation
- **Container runs as your host user** (same UID/GID)
- Files created by Claude Code maintain your ownership
- No `root:root` ownership issues
- No need for `sudo chown` after using the container

**How it works:**
1. Setup script detects your UID (e.g., 1000) and GID (e.g., 1000)
2. Docker builds container with matching user
3. Files created in `/workspace` are owned by your host user
4. Seamless workflow - edit files from host or container

Example:
```bash
# Before entering container
$ id
uid=1000(john) gid=1000(john)

# Inside container, Claude Code creates a file
$ echo "test" > /workspace/newfile.txt

# Back on host
$ ls -la ~/myproject/newfile.txt
-rw-r--r-- 1 john john 5 Oct 25 10:00 newfile.txt  ✅
# NOT owned by root!
```

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

**Note:** This will prevent Claude Code from accessing the Anthropic API and OAuth authentication. Use only for offline testing with a pre-authenticated session.

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

Each project gets its own isolated Claude Code settings. This allows you to:
- Use different Claude accounts for different projects
- Have different permission configurations per project
- Keep project-specific authentication tokens separate
- **Run multiple projects simultaneously** without port conflicts (when using non-OAuth mode)

### Switching to a Different Project

**Option 1: Run Projects Simultaneously (Recommended)**

Since containers use random ports in non-OAuth mode, you can run multiple projects at the same time:

1. Keep the current project running
2. Navigate to a different project directory
3. Clone this repository or copy the setup files
4. Run `./setup-and-run.sh` with the new project directory
5. Both containers run simultaneously without conflicts!

**Option 2: Switch Projects (One at a Time)**

1. Stop the current container:
```bash
docker-compose down
```

2. Update the `.env` file with the new project:
```bash
PROJECT_DIR=/path/to/different/project
PROJECT_NAME=different-project  # Different name = different settings
# USER_ID and GROUP_ID remain the same
```

3. Start the container:
```bash
docker-compose up -d
docker-compose exec claude-code bash
```

**Alternative:** Run the setup script again to interactively choose a new project. The script will automatically suggest a project name based on the directory path.

### Reusing Settings Across Projects

**OAuth credentials are automatically shared** across all projects via the `claude-credentials` volume.

If you want multiple projects to **share the same settings** (history, todos, permissions):

```bash
# In .env for both projects, use the same PROJECT_NAME
PROJECT_NAME=shared-config
# Both will use the same volume: claude-settings-shared-config
```

Both projects will use the same settings volume and permissions. OAuth credentials are shared regardless of PROJECT_NAME.

## ⚙️ Configuration

### Environment Variables (.env file)

- **PROJECT_DIR**: Absolute path to your project directory (required)
- **PROJECT_NAME**: Unique name for this project's Claude settings (required)
  - Must be a valid directory name (letters, numbers, dots, hyphens, underscores only)
  - Default: Last directory name from PROJECT_DIR
  - Used to create isolated volume: `claude-settings-${PROJECT_NAME}`
  - Example: `myapp`, `client-project`, `experiment_1`
- **USER_ID**: Your host user ID - auto-detected by setup script (required)
- **GROUP_ID**: Your host group ID - auto-detected by setup script (required)
- **USERNAME**: Container username, default is `node` (required)
- **ANTHROPIC_API_KEY**: Your Anthropic API key (optional if using OAuth)
- **ANTHROPIC_MODEL**: Claude model to use (default: claude-sonnet-4-5-20250929)
- **OAUTH_MODE**: (Optional, passed as command-line environment variable, NOT stored in .env)
  - Controls port binding for OAuth authentication
  - Set to `:8338` for OAuth setup: `OAUTH_MODE=":8338" docker-compose up -d`
  - Leave unset for normal use: `docker-compose up -d` (uses random port)
  - Only needed during initial OAuth authentication
  - After authentication, restart without OAUTH_MODE to allow multiple projects simultaneously

### Getting Your User IDs and Project Name

The setup script automatically detects these, but if setting up manually:

```bash
# Find your user ID
id -u
# Output: 1000 (example)

# Find your group ID
id -g
# Output: 1000 (example)

# Find your username
whoami
# Output: john (example)

# Suggested project name (from your project path)
basename /path/to/your/yourproject
# Output: yourproject (example)
```

**Project Name Rules:**
- Only letters (a-z, A-Z), numbers (0-9), dots (.), hyphens (-), and underscores (_)
- No spaces, slashes, or special characters
- Should be descriptive and unique per project
- Examples: `webapp`, `client-site`, `ml_experiment`, `project-2024`

### Claude Code Settings

Settings are persisted in per-project Docker volumes (`claude-settings-${PROJECT_NAME}`). To configure permissions:

1. Inside the container, create `~/.claude/settings.json`:

```bash
# Inside container
mkdir -p ~/.claude
cat > ~/.claude/settings.json << 'EOF'
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
EOF
```

2. Or use the interactive command:
```bash
claude
/permissions
```

**Note:** Each project gets its own volume mounted at `/home/node/.claude/`, so each project can have different permission configurations. OAuth credentials are shared across all projects via symlink to `/home/node/.claude-shared/.credentials.json`.

## 🔧 Authentication

### Option 1: OAuth (Recommended for Claude Pro/Max subscribers)

**Prerequisites:**
- Active Claude Pro ($20/month) or Claude Max ($100/month) subscription
- Port 8338 must be exposed (already configured in docker-compose.yml)

**Steps:**

1. Leave `ANTHROPIC_API_KEY` empty in your `.env` file

2. Start the container and run Claude Code:
```bash
docker-compose up -d
docker-compose exec claude-code bash
claude
```

3. Follow the OAuth flow (see [OAuth Setup Guide](OAUTH_SETUP_GUIDE.md))

**Note:** OAuth tokens are saved in the shared `claude-credentials` volume at `/home/node/.claude-shared/.credentials.json` and symlinked to each project's `/home/node/.claude/.credentials.json`. All projects share the same OAuth credentials by default.

### Option 2: API Key

1. Get your API key from https://console.anthropic.com/

2. Set `ANTHROPIC_API_KEY` in your `.env` file:
```bash
ANTHROPIC_API_KEY=sk-ant-api03-your-key-here
```

3. Restart the container:
```bash
docker-compose down
docker-compose up -d
```

### Re-authenticating or Switching Accounts

If your OAuth token expires or you need to authenticate with a different account:

**Quick method (with setup script):**
```bash
# Stop current container
docker-compose down

# Run setup script again - it handles OAuth mode automatically
./setup-and-run.sh

# After OAuth completes, the script will offer to restart in non-OAuth mode
```

**Manual method:**

1. Stop the container:
```bash
docker-compose down
```

2. Start in OAuth mode (required for authentication):
```bash
OAUTH_MODE=":8338" docker-compose up -d
docker-compose exec claude-code bash
```

3. Inside container, remove old authentication and re-authenticate:
```bash
# Remove shared credentials (affects all projects)
rm -f ~/.claude-shared/.credentials.json

# Or remove this project's entire settings (keeps credentials)
rm -rf ~/.claude/*

# Start Claude Code and authenticate
claude
# Choose option 2 (OAuth)
# Follow the authentication steps
```

4. After authentication completes, exit and restart in normal mode:
```bash
exit
docker-compose down && docker-compose up -d
```

**Why restart in non-OAuth mode?**
- Uses a random host port instead of fixed port 8338
- Allows multiple projects to run simultaneously without port conflicts
- OAuth authentication continues to work (tokens are already saved)
- Port 8338 is only needed during the initial authentication flow

## 📦 What's Installed

The container includes:
- Node.js 20 (Alpine Linux)
- npm (latest version)
- Claude Code CLI (latest version)
- Python 3 with pip (from Alpine repos)
- Git
- Common development tools (bash, curl, vim, nano)
- SSH client
- Build tools (gcc, make, etc.)
- sudo (configured for passwordless access)

## 🐛 Troubleshooting

### "Project directory not found"
Ensure you're using the **absolute path** to your project:
```bash
# Good
PROJECT_DIR=/home/username/projects/myapp

# Bad (relative paths don't work)
PROJECT_DIR=./myapp
PROJECT_DIR=~/projects/myapp  # Tilde may not expand in .env
```

### Files owned by wrong user after container use
This should not happen with the current setup. If it does:

1. Check your `.env` file has correct USER_ID and GROUP_ID:
```bash
cat .env | grep -E "USER_ID|GROUP_ID"
```

2. Verify they match your host user:
```bash
id -u  # Should match USER_ID in .env
id -g  # Should match GROUP_ID in .env
```

3. Rebuild the container with correct IDs:
```bash
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### "Permission denied" accessing files inside container
The container runs as your user, so you should have the same permissions as on the host.

If you need root access inside the container:
```bash
# The container user has passwordless sudo
docker-compose exec claude-code sudo <command>
```

### Container won't start
```bash
# Check logs
docker-compose logs

# Rebuild from scratch (WARNING: removes volumes)
docker-compose down -v
docker-compose build --no-cache
docker-compose up -d
```

**Note:** Using `-v` flag removes ALL volumes including:
- The current project's settings volume: `claude-settings-${PROJECT_NAME}`
- The shared credentials volume: `claude-credentials` (if no other containers use it)

To remove only the current project's settings volume:
```bash
# From host machine:
docker volume rm claude-settings-${PROJECT_NAME}

# Or to clear settings without removing volume (from inside container):
rm -rf ~/.claude/*
```

### Claude Code authentication fails
1. For OAuth: Ensure port 8338 is not blocked and you complete the browser flow
2. For API key: Verify your key is correct at https://console.anthropic.com/
3. Check internet connectivity: `docker-compose exec claude-code curl https://api.anthropic.com`

### Build fails with "gid '1000' in use" or "user already exists"
This is normal and handled by the Dockerfile. The build should continue successfully despite these messages. If the build actually fails:

1. Check the full error message:
```bash
docker-compose build --no-cache 2>&1 | tee build.log
```

2. See the [Docker Build Troubleshooting](Docker%20Build%20Troubleshooting.md) guide

### OAuth redirect doesn't work
1. Verify port 8338 is exposed in docker-compose.yml
2. Make sure `network_mode: none` is **commented out**
3. Try manually opening the URL in your browser
4. Check firewall isn't blocking localhost:8338

## 🎯 Use Cases

### ✅ Safe for:
- Testing Claude Code on unfamiliar projects
- Working on open-source code
- Experimenting with AI-generated code
- Learning Claude Code features
- Keeping your host system clean
- Preventing accidental file ownership issues

### ⚠️ Consider alternatives for:
- Projects requiring access to host SSH keys (mount them explicitly if needed)
- Projects needing host environment variables (pass them via docker-compose.yml)
- Workflows requiring host Docker access (requires Docker-in-Docker setup)
- Projects with database connections on host (use host networking or bridge network)

## 📝 Best Practices

1. **Always use Git** in your project directory for easy rollback
2. **Use descriptive project names** - makes it clear which settings belong to which project
3. **Review changes** before committing Claude Code's modifications
4. **Start with plan mode** to understand what Claude wants to do
5. **Set permission denials** for sensitive files in settings.json (per-project)
6. **Limit resources** appropriately in docker-compose.yml
7. **Regular backups** of your project directory
8. **Use the setup script** to ensure correct UID/GID mapping and project name
9. **Test file ownership** after first use to verify setup is correct
10. **Separate projects = separate settings** - use different PROJECT_NAME values

## 💰 Cost Considerations

### API vs. Subscription

**API Key (Pay-per-use):**
- Claude Sonnet 4.5: $3/million input tokens, $15/million output tokens
- Typical session: $0.01 - $0.50 depending on complexity
- Monthly cost varies with usage

**Claude Pro (OAuth):**
- $20/month fixed cost
- Includes Claude Code usage
- Better for regular daily use

**Claude Max (OAuth):**
- $100/month fixed cost
- Higher rate limits
- Best for heavy usage

**Recommendation:** For daily development work, Claude Pro with OAuth is typically more economical than API pay-per-use.

## 🔗 Additional Resources

- [Claude Code Documentation](https://docs.claude.com/en/docs/claude-code)
- [Claude Code Settings](https://docs.claude.com/en/docs/claude-code/settings)
- [Anthropic Console](https://console.anthropic.com/)
- [Anthropic Pricing](https://www.anthropic.com/pricing)
- [OAuth Setup Guide](OAUTH_SETUP_GUIDE.md) (detailed authentication instructions)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

This software is provided "as-is" without any warranty. The author is not liable for any damages or issues arising from the use of this Docker setup. Use at your own risk.

**Important Security Notice:**

This Docker setup provides filesystem isolation but should not be considered a complete security solution.

Users are responsible for:
- Reviewing and understanding the code before use
- Configuring appropriate permissions for their use case
- Backing up their projects before using Claude Code
- Monitoring API costs and usage
- Complying with Anthropic's Terms of Service
- Verifying file ownership is preserved correctly

**No liability is assumed for:**
- Data loss or corruption
- Unexpected API costs
- Security vulnerabilities
- File ownership or permission issues
- Any damages resulting from use of this software

**Recommendation:** Always use version control (Git) and test in isolated environments first.

## 🙏 Acknowledgments

- Claude Code by Anthropic
- Docker and Docker Compose
- The open-source community

---

**Questions or issues?** Check the troubleshooting guides or review the documentation links above.
