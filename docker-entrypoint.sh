#!/bin/bash
set -e

# This entrypoint script manages Claude Code credentials and settings:
# - OAuth credentials (.credentials.json) stored in SHARED volume
# - User identity (.claude-user.json) stored in SHARED volume
# - Per-project settings (.claude.json) stored in PER-PROJECT volume
#
# Strategy:
# - Shared: userID, firstStartTime, numStartups, installMethod, autoUpdates
# - Per-project: theme, tipsHistory, projects, cachedStatsigGates, etc.

USERNAME="${USERNAME:-node}"
CLAUDE_DIR="/home/${USERNAME}/.claude"
SHARED_DIR="/home/${USERNAME}/.claude-shared"
HOME_DIR="/home/${USERNAME}"
CREDENTIALS_FILE=".credentials.json"
USER_IDENTITY_FILE=".claude-user.json"
CLAUDE_JSON=".claude.json"

# Ensure directories exist
mkdir -p "${SHARED_DIR}" "${CLAUDE_DIR}"

echo "=== Claude Code Setup ==="

# ===== STEP 1: Handle OAuth Credentials =====
if [ -f "${SHARED_DIR}/${CREDENTIALS_FILE}" ]; then
    # Credentials exist in shared location - create symlink if needed
    if [ ! -L "${CLAUDE_DIR}/${CREDENTIALS_FILE}" ]; then
        rm -f "${CLAUDE_DIR}/${CREDENTIALS_FILE}"
        ln -sf "${SHARED_DIR}/${CREDENTIALS_FILE}" "${CLAUDE_DIR}/${CREDENTIALS_FILE}"
        echo "✓ Linked OAuth credentials from shared storage"
    fi
elif [ -f "${CLAUDE_DIR}/${CREDENTIALS_FILE}" ] && [ ! -L "${CLAUDE_DIR}/${CREDENTIALS_FILE}" ]; then
    # Migrate existing credentials to shared storage
    echo "Migrating OAuth credentials to shared storage..."
    mv "${CLAUDE_DIR}/${CREDENTIALS_FILE}" "${SHARED_DIR}/${CREDENTIALS_FILE}"
    ln -sf "${SHARED_DIR}/${CREDENTIALS_FILE}" "${CLAUDE_DIR}/${CREDENTIALS_FILE}"
    echo "✓ OAuth credentials migrated to shared storage"
else
    # No credentials yet - create symlink for when they're created
    ln -sf "${SHARED_DIR}/${CREDENTIALS_FILE}" "${CLAUDE_DIR}/${CREDENTIALS_FILE}" 2>/dev/null || true
fi

# ===== STEP 2: Handle User Identity =====
# NOTE: Extraction of user identity is now handled by claude-wrapper.sh
# This runs AFTER first successful authentication, not at container startup

# If shared user identity exists but local .claude.json doesn't, create it
if [ -f "${SHARED_DIR}/${USER_IDENTITY_FILE}" ] && [ ! -f "${HOME_DIR}/${CLAUDE_JSON}" ]; then
    # Validate that shared identity has valid values (not null)
    USER_ID_VALUE=$(jq -r '.userID // "null"' "${SHARED_DIR}/${USER_IDENTITY_FILE}" 2>/dev/null)
    NUM_STARTUPS=$(jq -r '.numStartups // "null"' "${SHARED_DIR}/${USER_IDENTITY_FILE}" 2>/dev/null)

    if [ "${USER_ID_VALUE}" != "null" ] && [ "${USER_ID_VALUE}" != "" ] && \
       [ "${NUM_STARTUPS}" != "null" ] && [ "${NUM_STARTUPS}" != "" ]; then
        echo "Creating new .claude.json from shared user identity..."

        # Read shared user identity
        USER_IDENTITY=$(cat "${SHARED_DIR}/${USER_IDENTITY_FILE}")

        # Create new .claude.json with merged data
        # Merge shared fields (auth-related) + empty per-project fields
        # Shared fields come from .claude-user.json (userID, oauthAccount, etc.)
        # Per-project fields start empty (theme, tipsHistory, projects, etc.)
        echo "${USER_IDENTITY}" | jq '. + {
            theme: "light",
            tipsHistory: {},
            cachedStatsigGates: {},
            cachedDynamicConfigs: {},
            projects: {}
        }' > "${HOME_DIR}/${CLAUDE_JSON}"

        chmod 600 "${HOME_DIR}/${CLAUDE_JSON}"
        echo "✓ Created .claude.json with shared user identity"
        echo "  Authentication will be skipped - you may be asked for preferences"
    else
        echo "⚠ Shared user identity has invalid values - removing corrupted file"
        rm -f "${SHARED_DIR}/${USER_IDENTITY_FILE}"
        echo "First run - you'll go through initial setup (login, preferences)"
        echo "After setup, your identity will be saved for other projects (by claude-wrapper.sh)"
    fi
elif [ ! -f "${SHARED_DIR}/${USER_IDENTITY_FILE}" ] && [ ! -f "${HOME_DIR}/${CLAUDE_JSON}" ]; then
    echo "First run - you'll go through initial setup (login, preferences)"
    echo "After setup, your identity will be saved for other projects (by claude-wrapper.sh)"
elif [ -f "${SHARED_DIR}/${USER_IDENTITY_FILE}" ] && [ -f "${HOME_DIR}/${CLAUDE_JSON}" ]; then
    echo "✓ Using existing configuration"
fi

echo "=== Setup Complete ==="
echo ""

# Execute the main command (usually /bin/bash)
exec "$@"
