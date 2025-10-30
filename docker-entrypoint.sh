#!/bin/bash
set -e

# This entrypoint script manages Claude Code credentials and settings:
# - Credentials are stored in a SHARED volume (.claude-shared) - authenticate once for all projects
# - Settings/history are stored in a PER-PROJECT volume (.claude) - isolated by PROJECT_NAME
# - A symlink bridges credentials from shared to per-project location

USERNAME="${USERNAME:-node}"
CLAUDE_DIR="/home/${USERNAME}/.claude"
SHARED_DIR="/home/${USERNAME}/.claude-shared"
CREDENTIALS_FILE=".credentials.json"

# Ensure directories exist
mkdir -p "${SHARED_DIR}" "${CLAUDE_DIR}"

# Handle credentials location and migration
if [ -f "${SHARED_DIR}/${CREDENTIALS_FILE}" ]; then
    # Credentials exist in shared location - create symlink if needed
    if [ ! -L "${CLAUDE_DIR}/${CREDENTIALS_FILE}" ]; then
        # Remove regular file if it exists (we're moving to symlink)
        rm -f "${CLAUDE_DIR}/${CREDENTIALS_FILE}"
        # Create symlink to shared credentials
        ln -sf "${SHARED_DIR}/${CREDENTIALS_FILE}" "${CLAUDE_DIR}/${CREDENTIALS_FILE}"
        echo "✓ Linked credentials from shared storage"
    fi
elif [ -f "${CLAUDE_DIR}/${CREDENTIALS_FILE}" ] && [ ! -L "${CLAUDE_DIR}/${CREDENTIALS_FILE}" ]; then
    # Credentials exist in project location but not in shared - migrate them
    echo "Migrating credentials to shared storage..."
    mv "${CLAUDE_DIR}/${CREDENTIALS_FILE}" "${SHARED_DIR}/${CREDENTIALS_FILE}"
    ln -sf "${SHARED_DIR}/${CREDENTIALS_FILE}" "${CLAUDE_DIR}/${CREDENTIALS_FILE}"
    echo "✓ Credentials migrated to shared storage"
else
    # No credentials exist yet - create symlink for when they're created
    ln -sf "${SHARED_DIR}/${CREDENTIALS_FILE}" "${CLAUDE_DIR}/${CREDENTIALS_FILE}" 2>/dev/null || true
fi

# Execute the main command (usually /bin/bash)
exec "$@"
