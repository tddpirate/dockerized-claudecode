#!/bin/bash
# Wrapper for claude binary that handles post-authentication identity extraction
# This ensures user identity is saved to shared storage AFTER first successful auth

set -e

USERNAME="${USERNAME:-node}"
HOME_DIR="/home/${USERNAME}"
SHARED_DIR="${HOME_DIR}/.claude-shared"
USER_IDENTITY_FILE=".claude-user.json"
CLAUDE_JSON="${HOME_DIR}/.claude.json"
CLAUDE_REAL="/usr/local/bin/claude-real"

# Run the real claude binary with all arguments
"${CLAUDE_REAL}" "$@"
EXIT_CODE=$?

# After claude exits, check if we need to extract user identity
# Only extract if:
# 1. Shared user identity doesn't exist yet
# 2. Local .claude.json now exists with userID (meaning auth just completed)
# 3. All required fields have valid (non-null) values
if [ ! -f "${SHARED_DIR}/${USER_IDENTITY_FILE}" ] && [ -f "${CLAUDE_JSON}" ]; then
    # Check if .claude.json has userID field with valid value (not null)
    # Also verify numStartups is a valid number (not null)
    USER_ID_VALUE=$(jq -r '.userID // "null"' "${CLAUDE_JSON}" 2>/dev/null)
    NUM_STARTUPS=$(jq -r '.numStartups // "null"' "${CLAUDE_JSON}" 2>/dev/null)

    if [ "${USER_ID_VALUE}" != "null" ] && [ "${USER_ID_VALUE}" != "" ] && \
       [ "${NUM_STARTUPS}" != "null" ] && [ "${NUM_STARTUPS}" != "" ]; then
        echo ""
        echo "=== Saving Authentication for Future Projects ==="

        # Extract shared fields to shared storage
        # These fields are required for Claude Code to skip authentication in new containers
        jq '{
            userID: .userID,
            firstStartTime: .firstStartTime,
            numStartups: .numStartups,
            installMethod: .installMethod,
            autoUpdates: .autoUpdates,
            hasCompletedOnboarding: .hasCompletedOnboarding,
            oauthAccount: .oauthAccount,
            lastOnboardingVersion: .lastOnboardingVersion,
            fallbackAvailableWarningThreshold: .fallbackAvailableWarningThreshold,
            sonnet45MigrationComplete: .sonnet45MigrationComplete,
            hasOpusPlanDefault: .hasOpusPlanDefault,
            claudeCodeFirstTokenDate: .claudeCodeFirstTokenDate
        }' "${CLAUDE_JSON}" > "${SHARED_DIR}/${USER_IDENTITY_FILE}"

        chmod 600 "${SHARED_DIR}/${USER_IDENTITY_FILE}"

        echo "✓ Authentication saved to shared storage"
        echo "✓ Other projects using this Docker setup will skip authentication"
        echo "=============================================="
        echo ""
    fi
fi

# Exit with the same code as claude
exit $EXIT_CODE
