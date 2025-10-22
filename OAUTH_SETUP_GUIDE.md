# OAuth Authentication for Claude Code in Docker

## 🎯 Overview

When using Claude Pro or Claude Max subscription, you can authenticate via OAuth instead of using an API key. This guide shows you how to set it up in the Docker container.

## 📋 Prerequisites

- Active **Claude Pro** ($20/month) or **Claude Max** ($100/month) subscription
- Docker container with **port 8338 exposed** (already configured in the updated docker-compose.yml)

## 🚀 Step-by-Step OAuth Setup

### Step 1: Start the Container Without API Key

Make sure your `.env` file has an **empty** API key:

```bash
# .env file
PROJECT_DIR=/path/to/your/project
ANTHROPIC_API_KEY=
ANTHROPIC_MODEL=claude-sonnet-4-5-20250929
```

### Step 2: Start the Container

```bash
# If using the setup script
./setup-and-run.sh

# Or manually
docker-compose up -d
docker-compose exec claude-code bash
```

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

**Select option 2** (Claude App - OAuth)

### Step 5: Complete OAuth Flow

Claude Code will:

1. **Display a URL** in the terminal, like:
   ```
   Please visit: https://claude.ai/auth/callback?code=...
   ```

2. **Automatically try to open your browser** (this may or may not work from Docker)

3. **Start a local server** on port 8338 to receive the OAuth callback

### Step 6: Open the URL in Your Host Browser

**Copy the URL from the terminal** and paste it into your **host machine's browser** (outside the container).

The URL should look like:
```
https://claude.ai/auth/callback?code=XXXXXX&state=YYYYYY
```

### Step 7: Authorize in Browser

In your browser:

1. **Sign in** to your Claude account (if not already logged in)
2. **Authorize** Claude Code to access your account
3. You'll see a success message
4. The browser will attempt to redirect to `localhost:8338`

### Step 8: Complete Authentication

Because port 8338 is forwarded from your host to the container:

- The OAuth callback will be received by the container
- Claude Code will complete authentication automatically
- You'll see a success message in the terminal

```
✓ Authentication successful!
Welcome to Claude Code
```

## 🎉 You're Done!

Claude Code is now authenticated with your Pro/Max subscription. Your authentication will be **persisted** in the `claude-settings` Docker volume, so you won't need to re-authenticate every time.

## 🔧 Troubleshooting

### "Cannot open browser" or "Browser not found"

This is **normal** in Docker. Just:
1. Copy the URL from the terminal
2. Paste it manually into your host browser
3. Complete the OAuth flow

### "Callback failed" or "Connection refused"

**Check port forwarding:**
```bash
# Make sure docker-compose.yml has:
ports:
  - "8338:8338"

# Restart container
docker-compose down
docker-compose up -d
```

### "Authentication timed out"

The OAuth flow has a timeout. If it expires:
1. Exit Claude Code (Ctrl+C)
2. Run `claude` again
3. Complete the flow faster this time

### OAuth doesn't work at all

**Fallback to API key:**
1. Get an API key from https://console.anthropic.com/
2. Add it to `.env` file:
   ```bash
   ANTHROPIC_API_KEY=sk-ant-api03-your-key-here
   ```
3. Restart container:
   ```bash
   docker-compose down
   docker-compose up -d
   ```

## 🔄 Re-authenticating

If your OAuth token expires or you want to switch accounts:

### Method 1: Clear Settings and Re-authenticate
```bash
# Inside container
rm -rf ~/.claude
claude
# Choose OAuth again
```

### Method 2: Delete Docker Volume
```bash
# On host machine
docker-compose down -v
docker-compose up -d
docker-compose exec claude-code bash
claude
# Choose OAuth again
```

## 🌐 Network Considerations

### OAuth Requires Internet Access

**Important:** OAuth authentication requires:
- ✅ Outbound internet access to `claude.ai`
- ✅ Port 8338 accessible for callback
- ❌ **Cannot use** `network_mode: none` (no network isolation)

If you need maximum security with network isolation, you must use an API key instead of OAuth.

### Firewall Settings

Make sure your firewall allows:
- Outbound HTTPS (443) to `claude.ai` and `anthropic.com`
- Inbound connections to `localhost:8338` (for OAuth callback)

## 💡 Best Practices

### For Development (Recommended: OAuth)
```yaml
# docker-compose.yml
ports:
  - "8338:8338"
# network_mode: none  # KEEP COMMENTED
```

✅ Use OAuth with Pro/Max subscription
✅ More cost-effective for regular use
✅ Higher rate limits

### For CI/CD or Automated Tasks (Use API Key)
```yaml
# docker-compose.yml
# ports:
#   - "8338:8338"
network_mode: none  # Enable for maximum isolation
```

✅ Use API key (set in `.env`)
✅ Works without browser interaction
✅ Can run completely isolated

## 📊 Cost Comparison

| Method | Monthly Cost | Best For |
|--------|--------------|----------|
| **API Key (Pay-per-use)** | Variable (~$20-100+) | Occasional use, CI/CD |
| **Claude Pro (OAuth)** | $20/month fixed | Regular development |
| **Claude Max (OAuth)** | $100/month fixed | Heavy usage, teams |

**Recommendation:** For daily Claude Code usage, OAuth with Pro/Max is typically more economical than pay-per-use API.

## ✅ Verification

After successful OAuth authentication, verify it's working:

```bash
# Inside container
claude

# You should see:
# - No authentication prompts
# - Claude Code starts immediately
# - Your subscription plan shown
```

## 🔗 Additional Resources

- [Claude Pricing](https://www.anthropic.com/pricing)
- [Claude Code Authentication Docs](https://docs.claude.com/en/docs/claude-code/setup)
- [Anthropic Console](https://console.anthropic.com/)

---

**Need help?** If OAuth isn't working after following these steps, fall back to using an API key as described in the main README.
