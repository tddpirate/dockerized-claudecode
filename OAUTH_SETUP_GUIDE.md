# OAuth Authentication for Claude Code in Docker

## 🎯 Overview

When using Claude Pro or Claude Max subscription, you can authenticate via OAuth instead of using an API key. This guide shows you how to set it up in the Docker container.

## 📋 Prerequisites

- Active **Claude Pro** ($20/month) or **Claude Max** ($100/month) subscription at https://claude.ai
- Docker container with **port 8338 exposed** (already configured in docker-compose.yml)
- Internet connection (OAuth requires network access)

## 🚀 Step-by-Step OAuth Setup

### Step 1: Start the Container Without API Key

Make sure your `.env` file has an **empty** API key:

```bash
# .env file
PROJECT_DIR=/path/to/your/project
USER_ID=1000
GROUP_ID=1000
USERNAME=claudeuser
ANTHROPIC_API_KEY=
ANTHROPIC_MODEL=claude-sonnet-4-5-20250929
```

**Note:** The setup script (`setup-and-run.sh`) creates this file with empty API key by default.

### Step 2: Start the Container

```bash
# If using the setup script
./setup-and-run.sh

# Or manually
docker-compose up -d
docker-compose exec claude-code bash
```

You should now be inside the container as your user (matching your host UID/GID).

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

Claude Code is now authenticated with your Pro/Max subscription. Your authentication token is **saved** in the `claude-settings` Docker volume at `/home/claudeuser/.claude`, so you won't need to re-authenticate every time you use the container.

## 🔧 Troubleshooting

### "Cannot open browser" or "Browser not found"

This is **normal and expected** in Docker. The container cannot open a browser on your host machine. Just:
1. Copy the URL shown in the terminal
2. Paste it manually into your host browser
3. Complete the OAuth flow

This is the standard workflow for Docker-based OAuth.

### "Callback failed" or "Connection refused"

**Check port forwarding:**

1. Verify docker-compose.yml has port 8338 exposed:
```bash
cat docker-compose.yml | grep -A2 ports
# Should show:
# ports:
#   - "8338:8338"
```

2. Check if port is actually listening:
```bash
# While OAuth is waiting, on host machine:
netstat -an | grep 8338
# or
lsof -i :8338
```

3. Restart container if needed:
```bash
docker-compose down
docker-compose up -d
docker-compose exec claude-code bash
claude
```

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
# Inside container
rm -rf ~/.claude
claude
# Choose OAuth (option 2) again and follow the steps
```

This preserves the container and only clears Claude Code settings.

### Method 2: Delete Docker Volume (Complete Reset)

```bash
# On host machine (outside container)
docker-compose down -v
docker-compose up -d
docker-compose exec claude-code bash
claude
# Choose OAuth (option 2) again
```

**Warning:** This deletes **all** persisted settings, not just authentication.

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
      - "8338:8338"  # Required for OAuth callback
    # network_mode: none  # Must be COMMENTED OUT for OAuth
```

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

OAuth tokens are stored in:
- **Container location:** `/home/claudeuser/.claude/`
- **Docker volume:** `claude-settings` (persistent across container restarts)
- **Not visible on host:** Tokens stay inside the Docker volume for security

### Token Lifecycle

- OAuth tokens are **long-lived** (typically months)
- Automatically refreshed by Claude Code when needed
- Invalidated if you change your Claude password
- Can be revoked from your Claude account settings

### Best Practices

1. **Don't share the claude-settings volume** between multiple users
2. **Use separate accounts** if multiple developers need access
3. **Revoke tokens** if you suspect compromise (via Claude account settings)
4. **Re-authenticate** after changing your Claude password

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
No. Each container has its own `claude-settings` volume. If you need multiple containers, you'll need to authenticate each one separately (or use the same volume, but that's not recommended).

---

**Need help?** If OAuth isn't working after following these steps, consider using an API key as described in the main README, or check the troubleshooting section above.
