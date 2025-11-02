FROM node:20-alpine

# Install required packages (including py3-pip from Alpine repos)
RUN apk update && apk add --no-cache \
    bash \
    curl \
    git \
    build-base \
    python3 \
    py3-pip \
    vim \
    nano \
    openssh-client \
    ca-certificates \
    tzdata \
    sudo \
    shadow \
    jq

# Upgrade npm to latest version (optional, can be removed if causes issues)
RUN npm install -g npm@latest

# Install Claude Code CLI globally
RUN npm install -g @anthropic-ai/claude-code

# Create a non-root user that will match the host user
# The UID and GID will be set at runtime via build args
ARG USER_ID=1000
ARG GROUP_ID=1000
ARG USERNAME=node

# Detect if user already exists with the target UID
# The node:20-alpine base image already has a 'node' user with UID 1000
# We'll reuse it instead of creating conflicts
RUN set -eux; \
    ACTUAL_USER=""; \
    ACTUAL_GROUP=""; \
    \
    # Check if the target UID already exists
    if getent passwd ${USER_ID} >/dev/null 2>&1; then \
        ACTUAL_USER=$(getent passwd ${USER_ID} | cut -d: -f1); \
        echo "✓ User ${USER_ID} already exists as '${ACTUAL_USER}' - using existing user"; \
        # Get the user's primary group
        ACTUAL_GROUP=$(id -gn ${ACTUAL_USER}); \
    else \
        echo "Creating new user '${USERNAME}' with UID ${USER_ID}"; \
        # Create group if needed
        if getent group ${GROUP_ID} >/dev/null 2>&1; then \
            ACTUAL_GROUP=$(getent group ${GROUP_ID} | cut -d: -f1); \
            echo "Group ${GROUP_ID} already exists as ${ACTUAL_GROUP}"; \
        else \
            addgroup -g ${GROUP_ID} ${USERNAME}; \
            ACTUAL_GROUP=${USERNAME}; \
            echo "Created group ${USERNAME} with GID ${GROUP_ID}"; \
        fi; \
        # Create user
        adduser -D -u ${USER_ID} -G ${ACTUAL_GROUP} ${USERNAME}; \
        ACTUAL_USER=${USERNAME}; \
        echo "Created user ${USERNAME} with UID ${USER_ID} in group ${ACTUAL_GROUP}"; \
    fi; \
    \
    # Store the actual username for later use
    echo "export ACTUAL_USERNAME=${ACTUAL_USER}" > /etc/profile.d/docker-user.sh

# Give user sudo access without password (for convenience)
# Use 'node' as default since that's what exists in base image
RUN SUDO_USER=$(getent passwd ${USER_ID} | cut -d: -f1) && \
    echo "${SUDO_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${SUDO_USER} && \
    chmod 0440 /etc/sudoers.d/${SUDO_USER}

# Create workspace directory and set permissions
WORKDIR /workspace
RUN chown -R ${USER_ID}:${GROUP_ID} /workspace

# Ensure Claude Code global installation is accessible
RUN chmod -R a+rx /usr/local/lib/node_modules/@anthropic-ai

# Create home directory for the user if it doesn't exist
# Determine actual username and ensure home directory exists
RUN ACTUAL_USER=$(getent passwd ${USER_ID} | cut -d: -f1) && \
    mkdir -p /home/${ACTUAL_USER} && \
    chown -R ${USER_ID}:${GROUP_ID} /home/${ACTUAL_USER}

# Create .claude directories for settings
# - .claude: per-project settings (mounted as volume)
# - .claude-shared: shared credentials across all projects (mounted as volume)
RUN ACTUAL_USER=$(getent passwd ${USER_ID} | cut -d: -f1) && \
    mkdir -p /home/${ACTUAL_USER}/.claude /home/${ACTUAL_USER}/.claude-shared && \
    chown -R ${USER_ID}:${GROUP_ID} /home/${ACTUAL_USER}/.claude /home/${ACTUAL_USER}/.claude-shared

# Add entrypoint script to manage credentials and settings
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Add wrapper script for claude binary
# This extracts user identity to shared storage after first authentication
COPY claude-wrapper.sh /usr/local/bin/claude-wrapper.sh
RUN chmod +x /usr/local/bin/claude-wrapper.sh

# Rename real claude binary and replace with wrapper
RUN mv /usr/local/bin/claude /usr/local/bin/claude-real && \
    ln -s /usr/local/bin/claude-wrapper.sh /usr/local/bin/claude

# Switch to non-root user (using numeric IDs for reliability)
USER ${USER_ID}:${GROUP_ID}

# Set bash as default shell
SHELL ["/bin/bash", "-c"]

# Verify installation (this will create .claude.json and possibly .claude-user.json)
# We need to clean these up so they don't interfere with the real authentication flow
RUN claude --version || echo "Claude Code installed, authentication needed on first run" && \
    ACTUAL_USER=$(getent passwd ${USER_ID} | cut -d: -f1) && \
    rm -f /home/${ACTUAL_USER}/.claude.json /home/${ACTUAL_USER}/.claude-shared/.claude-user.json && \
    echo "✓ Cleaned up verification artifacts"

# Set entrypoint to manage credentials symlink
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Default command: start interactive bash
CMD ["/bin/bash"]
