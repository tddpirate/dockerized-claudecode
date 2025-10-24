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
    shadow

# Upgrade npm to latest version (optional, can be removed if causes issues)
RUN npm install -g npm@latest

# Install Claude Code CLI globally
RUN npm install -g @anthropic-ai/claude-code

# Create a non-root user that will match the host user
# The UID and GID will be set at runtime via build args
ARG USER_ID=1000
ARG GROUP_ID=1000
ARG USERNAME=claudeuser

# Create group and user with specified IDs
# Handle cases where GID/UID might already exist in base image
RUN set -eux; \
    ACTUAL_GROUP=""; \
    if getent group ${GROUP_ID} >/dev/null 2>&1; then \
        ACTUAL_GROUP=$(getent group ${GROUP_ID} | cut -d: -f1); \
        echo "Group ${GROUP_ID} already exists as ${ACTUAL_GROUP}"; \
    else \
        addgroup -g ${GROUP_ID} ${USERNAME}; \
        ACTUAL_GROUP=${USERNAME}; \
        echo "Created group ${USERNAME} with GID ${GROUP_ID}"; \
    fi; \
    if getent passwd ${USER_ID} >/dev/null 2>&1; then \
        EXISTING_USER=$(getent passwd ${USER_ID} | cut -d: -f1); \
        echo "User ${USER_ID} already exists as ${EXISTING_USER}"; \
    else \
        adduser -D -u ${USER_ID} -G ${ACTUAL_GROUP} ${USERNAME}; \
        echo "Created user ${USERNAME} with UID ${USER_ID} in group ${ACTUAL_GROUP}"; \
    fi

# Give user sudo access without password (for convenience)
RUN echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} && \
    chmod 0440 /etc/sudoers.d/${USERNAME}

# Create workspace directory and set permissions
WORKDIR /workspace
RUN chown -R ${USER_ID}:${GROUP_ID} /workspace

# Ensure Claude Code global installation is accessible
RUN chmod -R a+rx /usr/local/lib/node_modules/@anthropic-ai

# Create home directory for the user if it doesn't exist
RUN mkdir -p /home/${USERNAME} && \
    chown -R ${USER_ID}:${GROUP_ID} /home/${USERNAME}

# Create .claude directory for settings
RUN mkdir -p /home/${USERNAME}/.claude && \
    chown -R ${USER_ID}:${GROUP_ID} /home/${USERNAME}/.claude

# Switch to non-root user (using numeric IDs for reliability)
USER ${USER_ID}:${GROUP_ID}

# Set bash as default shell
SHELL ["/bin/bash", "-c"]

# Verify installation
RUN claude --version || echo "Claude Code installed, authentication needed on first run"

# Default command: start interactive bash
CMD ["/bin/bash"]
