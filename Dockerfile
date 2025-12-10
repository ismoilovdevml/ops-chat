# ============================================
# Stage 1: Build
# ============================================
FROM elixir:1.16-otp-26-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    nodejs \
    npm

# Set environment
ENV MIX_ENV=prod

WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy dependency files
COPY mix.exs mix.lock ./
COPY config config

# Install dependencies
RUN mix deps.get --only prod
RUN mix deps.compile

# Copy assets
COPY assets assets
COPY priv priv

# Build assets
RUN mix assets.deploy

# Copy source code
COPY lib lib

# Compile application
RUN mix compile

# Build release
RUN mix release

# ============================================
# Stage 2: Runtime
# ============================================
FROM alpine:3.19 AS runtime

# Install runtime dependencies
RUN apk add --no-cache \
    libstdc++ \
    openssl \
    ncurses-libs \
    openssh-client \
    curl \
    bash

WORKDIR /app

# Create non-root user
RUN addgroup -g 1000 ops && \
    adduser -u 1000 -G ops -s /bin/sh -D ops

# Copy release from builder
COPY --from=builder --chown=ops:ops /app/_build/prod/rel/ops_chat ./

# Create data directory for SQLite
RUN mkdir -p /app/data && chown ops:ops /app/data

# Set environment variables
ENV HOME=/app
ENV MIX_ENV=prod
ENV PHX_SERVER=true
ENV DATABASE_PATH=/app/data/ops_chat.db

# Switch to non-root user
USER ops

# Expose port
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:4000/health || exit 1

# Start application
CMD ["bin/ops_chat", "start"]
