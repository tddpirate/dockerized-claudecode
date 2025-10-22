FROM node:20-alpine

# Install required packages
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
    tzdata

# Install Claude Code CLI globally
RUN npm install -g @anthropic-ai/claude-code

# Create workspace directory
WORKDIR /workspace

# Verify installation
RUN claude --version || echo "Claude Code installed, authentication needed on first run"

# Set bash as default shell
SHELL ["/bin/bash", "-c"]

# Default command: start interactive bash
# Users will run 'claude' manually after container starts
CMD ["/bin/bash"]
