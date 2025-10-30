# OAuth Authentication for Claude Code in Docker

## 🎯 Overview

When using Claude Pro or Claude Max subscription, you can authenticate via OAuth instead of using an API key. This guide shows you how to set it up in the Docker container.

## 📋 Prerequisites

- Active **Claude Pro** ($20/month) or **Claude Max** ($100/month) subscription at https://claude.ai
- Docker container with **port 8338 exposed** (already configured in docker-compose.yml)
- Internet connection (OAuth requires network access)
- **PROJECT_NAME** configured in .env (set automatically by setup-and-run.sh)

## 🚀 Step-by-Step OAuth Setup

### Step 1: Start the Container Without API Key

Make sure your `.env` file has an **empty** API key:

```bash
# .env file
PROJECT_DIR=/path/to/your/project
PROJECT_NAME=myproject
USER_ID=1000
GROUP_ID=1000
USERNAME=node
ANTHROPIC_API_KEY=
ANTHROPIC_MODEL=claude-sonnet-4-5-20250929
```

**Note:** The setup script (`setup-and-run.sh`) creates this file with empty API key by default.

### Step 2: Start the Container

```bash
# If using the setup script (recommended)
./setup-and-run.sh

# Or manually for OAuth setup
OAUTH_MODE=":8338" docker-compose up -d
docker-compose exec claude-code bash
```

**Important Notes:**
- The setup script automatically starts the container in **OAuth mode** (port 8338:8338 exposed)
- OAuth mode is only needed during initial authentication
- After authentication completes, the setup script will offer to restart in **non-OAuth mode**
- Non-OAuth mode uses a random host port, allowing multiple projects to run simultaneously without port conflicts
- You should now be inside the container as your user (matching your host UID/GID)

### Step 3: Launch Claude Code for First Time

Inside the container, run:

```bash
claude
```

### Step 4: Choose Authentication Method

Claude Code will prompt you with authentication options:

```
How would you like to authenticate?
1. Anthropic Console (API key)
2. Claude App (OAuth - Pro/Max subscription)
3. Amazon Bedrock
4. Google Vertex AI

Choose [1-4]:
```

**Type `2` and press Enter** to select Claude App OAuth.

### Step 5: Complete OAuth Flow

Claude Code will:

1. **Display a URL** in the terminal, something like:
   ```
   Please visit: https://claude.ai/oauth/authorize?client_id=...&redirect_uri=http://localhost:8338/callback&...
   
   Waiting for authentication...
   ```

2. **Attempt to open your browser** (this won't work from inside Docker - that's expected)

3. **Start a local server** on port 8338 to receive the OAuth callback

### Step 6: Open the URL in Your Host Browser

**Copy the entire URL from the terminal** and paste it into your **host machine's browser** (outside the container).

The URL should look similar to:
```
https://claude.ai/oauth/authorize?client_id=XXXXXX&redirect_uri=http://localhost:8338/callback&state=YYYYYY&...
```

**Important:** You must open this URL on your **host machine**, not inside the container.

### Step 7: Authorize in Browser

In your browser:

1. **Sign in** to your Claude account (if not already logged in)
   - Use the same credentials you use at https://claude.ai
   - Must have an active Claude Pro or Max subscription

2. **Review the permissions** Claude Code is requesting
   - Typically: Access to Claude API
   - Use your subscription for API calls

3. **Click "Authorize"** or **"Allow"**

4. You'll see a success message

5. The browser will attempt to redirect to `http://localhost:8338/callback?code=...`

### Step 8: Complete Authentication

Because port 8338 is forwarded from your host to the container:

1. The OAuth callback is **received by the container** via the forwarded port
2. Claude Code **automatically completes** the authentication
3. You'll see a success message in the terminal:

```
✓ Authentication successful!
✓ Connected with Claude Pro account
Welcome to Claude Code!

Ready to start coding. Type /help for available commands.
```

## 🎉 You're Done!

Claude Code is now authenticated with your Pro/Max subscription. Your authentication token is **saved** in the shared `claude-credentials` Docker volume at `/home/node/.claude-shared/.credentials.json` and symlinked to `/home/node/.claude/.credentials.json`. You won't need to re-authenticate for any project using this Docker setup.

### Switching to Non-OAuth Mode (Recommended)

After completing authentication, **exit the container** (type `exit` or press Ctrl+D).

The setup script will prompt you to restart the container in non-OAuth mode:

```
Do you want to restart the container in non-OAuth mode now? (Y/n):
```

**Press Y (recommended)** to:
- ✅ Use a random host port instead of fixed port 8338
- ✅ Allow multiple projects to run simultaneously without port conflicts
- ✅ Maintain OAuth authentication (tokens are already saved)
- ✅ No need to re-authenticate

After restart, OAuth authentication continues to work normally - the port is only needed during the initial authentication flow.

**Note:** OAuth credentials are shared across all projects via the `claude-credentials` volume. However, each project has its own settings volume (`claude-settings-${PROJECT_NAME}`) for:
- Project-specific history and todos
- Project-specific permissions
- Independent session state

All projects share the same OAuth authentication by default.

## 🔧 Troubleshooting

### "Cannot open browser" or "Browser not found"

This is **normal and expected** in Docker. The container cannot open a browser on your host machine. Just:
1. Copy the URL shown in the terminal
2. Paste it manually into your host browser
3. Complete the OAuth flow

This is the standard workflow for Docker-based OAuth.

### "Callback failed" or "Connection refused"

**Check port forwarding:**

1. Verify the container is running in OAuth mode:
```bash
# Container must be started with OAuth mode for initial authentication
docker-compose down
OAUTH_MODE=":8338" docker-compose up -d
docker-compose exec claude-code bash
claude
```

2. Check if port is actually listening:
```bash
# While OAuth is waiting, on host machine:
netstat -an | grep 8338
# or
lsof -i :8338
```

3. Verify docker-compose.yml has the OAUTH_MODE port configuration:
```bash
cat docker-compose.yml | grep -A2 ports
# Should show:
# ports:
#   - "8338${OAUTH_MODE:-}"
```

**Note:** The setup script (`./setup-and-run.sh`) automatically handles OAuth mode. Use it for initial setup!

### "Authentication requires Claude Pro or Max subscription"

You'll see this error if:
- You have a **free Claude account** (OAuth requires paid subscription)
- Your Pro/Max subscription has **expired**
- You're signed into the **wrong account** in the browser

**Solution:**
- Subscribe at https://claude.ai (Pro: $20/month, Max: $100/month)
- Verify your subscription is active
- Make sure you're signing into the correct Claude account

### "Authentication timed out"

The OAuth flow has a timeout (usually a few minutes). If it expires:

1. Press `Ctrl+C` in the terminal to cancel
2. Run `claude` again to restart the authentication process
3. Complete the browser flow **faster** this time

**Tips to avoid timeout:**
- Have your Claude account login ready before starting
- Copy the URL immediately when displayed
- Don't wait too long between steps

### OAuth doesn't work at all

**Possible causes and solutions:**

1. **Port 8338 is blocked by firewall:**
   ```bash
   # Check if firewall is blocking the port
   # On Linux:
   sudo ufw status
   # On macOS:
   sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
   ```

2. **Network mode is set to 'none':**
   ```bash
   # Check docker-compose.yml
   cat docker-compose.yml | grep network_mode
   # If uncommented, OAuth won't work - comment it out
   ```

3. **Another service is using port 8338:**
   ```bash
   # Check what's using the port
   lsof -i :8338
   # Stop conflicting service or change port in docker-compose.yml
   ```

**Fallback to API key:**

If OAuth continues to fail, use an API key instead:

1. Get an API key from https://console.anthropic.com/
2. Add it to `.env` file:
   ```bash
   ANTHROPIC_API_KEY=sk-ant-api03-your-key-here
   ```
3. Restart container:
   ```bash
   docker-compose down
   docker-compose up -d
   docker-compose exec claude-code bash
   claude
   ```

## 🔄 Re-authenticating

If your OAuth token expires or you want to switch accounts:

### Method 1: Clear Settings and Re-authenticate (Recommended)

```bash
# Step 1: Stop the container
docker-compose down

# Step 2: Start in OAuth mode (required for authentication)
OAUTH_MODE=":8338" docker-compose up -d
docker-compose exec claude-code bash

# Step 3: Inside container - remove shared credentials (affects all projects)
rm -f ~/.claude-shared/.credentials.json

# Or remove this project's settings (keeps credentials)
rm -rf ~/.claude/*

# Step 4: Restart Claude Code and authenticate
claude
# Choose OAuth (option 2) again and follow the steps

# Step 5: After authentication, exit container and restart in non-OAuth mode
exit
docker-compose down && docker-compose up -d
```

This preserves the container and only clears Claude Code settings for this project.

### Method 2: Delete Docker Volume (Complete Reset)

```bash
# On host machine (outside container)

# Option A: Remove shared credentials (affects all projects)
docker volume rm claude-credentials

# Option B: Remove only this project's settings volume
docker volume rm claude-settings-${PROJECT_NAME}

# Option C: Remove both
docker volume rm claude-credentials
docker volume rm claude-settings-${PROJECT_NAME}

# Then start in OAuth mode for re-authentication
OAUTH_MODE=":8338" docker-compose up -d
docker-compose exec claude-code bash

# Re-authenticate
claude
# Choose OAuth (option 2) again

# After authentication, exit and restart in non-OAuth mode
exit
docker-compose down && docker-compose up -d
```

**Warning:** Removing `claude-credentials` affects **all projects**. Removing a specific `claude-settings-${PROJECT_NAME}` volume only affects that project's settings (history, todos, permissions).

## 🌐 Network Considerations

### OAuth Requires Internet Access

**Important:** OAuth authentication requires:
- ✅ Outbound HTTPS access to `claude.ai` and `anthropic.com`
- ✅ Port 8338 accessible for OAuth callback
- ❌ **Cannot use** `network_mode: none` (disables all networking)

### Docker Compose Configuration

For OAuth to work, your `docker-compose.yml` must have:

```yaml
services:
  claude-code:
    ports:
      - "8338${OAUTH_MODE:-}"  # OAuth mode controls port binding
    # network_mode: none  # Must be COMMENTED OUT for OAuth
```

**Port binding modes:**
- **OAuth mode** (during authentication): Start with `OAUTH_MODE=":8338" docker-compose up -d`
  - Binds to fixed port 8338:8338 for OAuth callback
- **Normal mode** (after authentication): Start with `docker-compose up -d`
  - Uses random host port, allows multiple projects simultaneously
  - OAuth authentication still works (tokens are saved)

If you need maximum security with network isolation, you **must use an API key** instead of OAuth.

### Firewall Settings

Make sure your firewall allows:
- **Outbound HTTPS (port 443)** to `claude.ai` and `anthropic.com`
- **Inbound connections to `localhost:8338`** (for OAuth callback)

Most default firewall configurations allow both of these by default.

### Corporate Networks / VPNs

If you're on a corporate network or VPN:
- OAuth may be blocked by corporate firewall
- Port 8338 callback may not work
- Consider using API key authentication instead
- Or contact your IT department about allowing claude.ai OAuth

## 💡 Best Practices

### For Development (Recommended: OAuth)

```yaml
# docker-compose.yml
ports:
  - "8338:8338"
# network_mode: none  # KEEP COMMENTED for OAuth
```

**Advantages:**
- ✅ Fixed monthly cost ($20 or $100)
- ✅ More cost-effective for regular use
- ✅ Higher rate limits than pay-per-use
- ✅ Simple authentication flow

### For CI/CD or Automated Tasks (Use API Key)

```yaml
# docker-compose.yml
# ports:
#   - "8338:8338"  # Can be commented out
network_mode: none  # Enable for maximum isolation
```

**Set in .env:**
```bash
ANTHROPIC_API_KEY=sk-ant-api03-your-key-here
```

**Advantages:**
- ✅ Works without browser interaction
- ✅ Can run completely isolated (no network)
- ✅ Better for automated workflows
- ✅ No OAuth token expiration concerns

## 📊 Cost Comparison

| Method | Monthly Cost | Best For |
|--------|--------------|----------|
| **API Key (Pay-per-use)** | Variable (~$10-100+) | Occasional use, CI/CD, automation |
| **Claude Pro (OAuth)** | $20/month fixed | Regular daily development work |
| **Claude Max (OAuth)** | $100/month fixed | Heavy usage, professional developers, teams |

### Usage Estimation

**Light usage** (5-10 Claude Code sessions/day):
- API: ~$10-20/month
- Pro: $20/month ← Better choice

**Moderate usage** (20-30 sessions/day):
- API: ~$30-60/month
- Pro: $20/month ← Much better
- Max: $100/month if you hit Pro limits

**Heavy usage** (50+ sessions/day):
- API: ~$80-200+/month
- Max: $100/month ← Better choice

**Recommendation:** For daily Claude Code usage, OAuth with Pro/Max is typically more economical than pay-per-use API.

## ✅ Verification

After successful OAuth authentication, verify it's working:

```bash
# Inside container
claude

# You should see:
# - No authentication prompts
# - Claude Code starts immediately
# - Possibly a message showing your subscription plan
```

You can also check your authentication status:

```bash
# List Claude Code settings
ls -la ~/.claude/

# Should show configuration files including auth tokens
```

## 🔐 Security Notes

### Token Storage

OAuth tokens are stored in a shared volume accessible to all projects:
- **Container location:** `/home/node/.claude-shared/.credentials.json` (actual storage)
- **Symlinked to:** `/home/node/.claude/.credentials.json` (for each project)
- **Docker volume:** `claude-credentials` (shared across all projects)
- **Not visible on host:** Tokens stay inside the Docker volume for security
- **Shared by default:** All projects use the same OAuth credentials via the shared volume

### Token Lifecycle

- OAuth tokens are **long-lived** (typically months)
- Automatically refreshed by Claude Code when needed
- Invalidated if you change your Claude password
- Can be revoked from your Claude account settings

### Best Practices

1. **Don't share the claude-credentials volume** between multiple users
2. **Use separate Docker hosts or credentials volumes** if multiple developers need different accounts
3. **Revoke tokens** if you suspect compromise (via Claude account settings)
4. **Re-authenticate** after changing your Claude password
5. **All projects share credentials** - this is by design for convenience

## 🗂️ Multiple Projects and OAuth

### Shared OAuth Credentials

**Important:** All projects share the same OAuth credentials via the `claude-credentials` volume:

```bash
# Project A
PROJECT_NAME=client-work
# Volume: claude-settings-client-work (project-specific settings)
# Credentials: Shared from claude-credentials volume
# Location: /home/node/.claude/ → /home/node/.claude-shared/.credentials.json

# Project B
PROJECT_NAME=personal-project
# Volume: claude-settings-personal-project (project-specific settings)
# Credentials: Shared from claude-credentials volume (same as Project A)
# Location: /home/node/.claude/ → /home/node/.claude-shared/.credentials.json

# All projects use the SAME OAuth credentials automatically
```

### Benefits of Current Architecture

1. **Authenticate once, use everywhere** - Single OAuth login works for all projects
2. **Per-project settings isolation** - Each project has its own history, todos, and permissions
3. **Easy cleanup** - Remove settings for one project without affecting others
4. **Shared credentials** - No need to re-authenticate when switching projects
5. **Flexible settings sharing** - Multiple projects can share settings by using same PROJECT_NAME

### Managing Volumes and Settings

**List Claude-related volumes:**
```bash
docker volume ls | grep claude
```

**Output example:**
```
claude-credentials              (shared OAuth tokens)
claude-settings-projectA        (project A settings)
claude-settings-projectB        (project B settings)
```

**View shared credentials:**
```bash
# From host machine
docker run --rm -v claude-credentials:/data alpine ls -la /data

# Or from inside any container
ls -la ~/.claude-shared/
```

**Remove settings for specific project:**
```bash
# From host machine
docker volume rm claude-settings-<projectname>

# Or from inside the container (clears content, keeps volume)
rm -rf ~/.claude/*
```

**Remove shared credentials (affects all projects):**
```bash
# From host machine
docker volume rm claude-credentials

# Or from inside any container
rm -f ~/.claude-shared/.credentials.json
```

### Switching Between Projects

When you switch projects (change PROJECT_NAME in .env):

1. Stop current container: `docker-compose down`
2. Update PROJECT_NAME in .env to different project
3. Start new container: `docker-compose up -d`
4. New container mounts different settings volume (`claude-settings-${PROJECT_NAME}`)
5. OAuth credentials are automatically available (shared via `claude-credentials` volume)
6. No re-authentication needed - credentials are already there!

**Example workflow:**
```bash
# Working on client project
echo "PROJECT_NAME=client-work" >> .env
docker-compose up -d
docker-compose exec claude-code bash
claude  # Uses shared OAuth credentials (already authenticated)

# Switch to personal project
docker-compose down
sed -i 's/PROJECT_NAME=.*/PROJECT_NAME=personal-project/' .env
docker-compose up -d
docker-compose exec claude-code bash
claude  # Uses same OAuth credentials (no re-authentication needed)

# Note: Both projects use the same OAuth account
# If you need different accounts, you need separate credential volumes
```

## 🔗 Additional Resources

- [Claude Pricing](https://www.anthropic.com/pricing) - Compare Pro vs Max
- [Claude Code Setup Docs](https://docs.claude.com/en/docs/claude-code/setup) - Official documentation
- [Anthropic Console](https://console.anthropic.com/) - For API key management
- [Claude Account Settings](https://claude.ai/settings) - Manage subscriptions and OAuth apps

## ❓ FAQ

### Can I use my free Claude account with OAuth?
No. OAuth authentication requires a Claude Pro or Claude Max paid subscription. Free accounts must use API keys with pay-per-use billing.

### Does OAuth work on Windows/WSL2?
Yes! The setup works identically on Windows with WSL2. Just make sure Docker Desktop is running and port 8338 is accessible.

### Can I switch between OAuth and API key?
Yes! Simply change the `ANTHROPIC_API_KEY` in your `.env` file and restart the container. Empty = OAuth, filled = API key.

### How do I know which authentication method I'm using?
When you start Claude Code, it will indicate whether you're using a subscription (OAuth) or API key. You can also check by looking at your `.env` file - empty `ANTHROPIC_API_KEY` means OAuth.

### What happens if my subscription expires?
Claude Code will stop working and prompt you to re-authenticate. You'll need to either renew your subscription or switch to API key authentication.

### Can multiple containers share the same OAuth authentication?
**Yes, all containers automatically share the same OAuth credentials** via the `claude-credentials` volume. This is by design - authenticate once, use everywhere. Each PROJECT_NAME gets its own settings volume for history/todos/permissions, but credentials are shared.

### Can different projects use different Claude accounts?
**Not by default.** All projects share the same OAuth credentials via the `claude-credentials` volume. If you need different accounts for different projects, you would need to:
1. Create separate credential volumes with different names
2. Modify docker-compose.yml to use different credential volume names per project
3. This is not the default configuration and requires manual setup

### What happens when I switch PROJECT_NAME in .env?
The container will mount a different settings volume (`claude-settings-${NEW_PROJECT_NAME}`). OAuth credentials are automatically available via the shared `claude-credentials` volume, so no re-authentication is needed. Each project name gets its own settings (history, todos, permissions), but all share the same login.

### Can I share settings between projects?
**OAuth credentials are always shared** - that happens automatically via the `claude-credentials` volume. If you want to share settings (history, todos, permissions) between projects, use the same PROJECT_NAME in the .env file for both projects. They'll use the same `claude-settings-${PROJECT_NAME}` volume.

### How do I see all my project volumes?
Each project has its own settings volume. To see all volumes:

```bash
# From host machine
docker volume ls | grep claude
```

Example output:
```
claude-credentials              (shared OAuth for all projects)
claude-settings-project1        (settings for project1)
claude-settings-project2        (settings for project2)
claude-settings-work            (settings for work)
```

All projects share `claude-credentials`, but each has its own settings volume.

### How do I remove settings for a specific project?
```bash
# Remove the settings volume for a specific project (from host)
docker volume rm claude-settings-<PROJECT_NAME>

# Or clear settings without removing volume (from inside container)
rm -rf ~/.claude/*
```
Replace `<PROJECT_NAME>` with your actual project name. This removes only that project's settings. **Note:** OAuth credentials are shared, so this won't affect authentication - only project-specific history, todos, and permissions.

### How do I remove OAuth authentication completely?
```bash
# Remove shared credentials (affects ALL projects)
docker volume rm claude-credentials

# Or from inside any container
rm -f ~/.claude-shared/.credentials.json
```

---

**Need help?** If OAuth isn't working after following these steps, consider using an API key as described in the main README, or check the troubleshooting section above.
