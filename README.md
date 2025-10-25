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
USERNAME=claudeuser
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
- Each project has its own Claude Code settings and authentication
- Settings stored in: `/home/claudeuser/.claude/<PROJECT_NAME>`
- Different projects can use different Claude accounts or API keys
- Prevents configuration conflicts between projects
- Easy to reset settings for a specific project without affecting others

**Example:**
```bash
# Project A uses OAuth with Claude Pro
PROJECT_NAME=projectA

# Project B uses API key
PROJECT_NAME=projectB

# Each has separate settings, tokens, and configurations
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

### Switching to a Different Project

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

If you want multiple projects to **share** the same Claude Code settings:

```bash
# In .env for both projects, use the same PROJECT_NAME
PROJECT_NAME=shared-config
```

Both projects will use the same OAuth tokens, permissions, and configuration.

## ⚙️ Configuration

### Environment Variables (.env file)

- **PROJECT_DIR**: Absolute path to your project directory (required)
- **PROJECT_NAME**: Unique name for this project's Claude settings (required)
  - Must be a valid directory name (letters, numbers, dots, hyphens, underscores only)
  - Default: Last directory name from PROJECT_DIR
  - Used to isolate Claude Code settings per-project
  - Example: `myapp`, `client-project`, `experiment_1`
- **USER_ID**: Your host user ID - auto-detected by setup script (required)
- **GROUP_ID**: Your host group ID - auto-detected by setup script (required)
- **USERNAME**: Container username, default is `claudeuser` (required)
- **ANTHROPIC_API_KEY**: Your Anthropic API key (optional if using OAuth)
- **ANTHROPIC_MODEL**: Claude model to use (default: claude-sonnet-4-5-20250929)

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

Settings are persisted in Docker volumes, one per project. To configure permissions:

1. Inside the container, create `~/.claude/<PROJECT_NAME>/settings.json`:

```bash
# Inside container
mkdir -p ~/.claude/$PROJECT_NAME
cat > ~/.claude/$PROJECT_NAME/settings.json << 'EOF'
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

**Note:** Settings are stored per-project in `/home/claudeuser/.claude/<PROJECT_NAME>/`, so each project can have different permission configurations.

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

3. Follow the OAuth flow (see [OAuth Setup Guide](OAuth%20Setup%20Guide.md))

**Note:** OAuth tokens are saved per-project in the `claude-settings-<PROJECT_NAME>` volume. Each project can authenticate with a different Claude account if needed.

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

# Rebuild from scratch
docker-compose down -v
docker-compose build --no-cache
docker-compose up -d
```

**Note:** Using `-v` flag removes volumes including Claude settings for ALL projects. To remove only current project's settings:
```bash
docker volume rm claude-code_claude-settings-${PROJECT_NAME}
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
- [Claude Code Best Practices](https://www.anthropic.com/engineering/claude-code-best-practices)
- [Anthropic Console](https://console.anthropic.com/)
- [Anthropic Pricing](https://www.anthropic.com/pricing)
- [OAuth Setup Guide](OAuth%20Setup%20Guide.md) (detailed authentication instructions)
- [File Ownership Solution Guide](File%20Ownership%20Solution%20Guide.md) (technical details)

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
