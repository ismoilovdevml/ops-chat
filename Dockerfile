# ============================================
# Stage 1: Build
# ============================================
FROM elixir:1.17-otp-27-alpine AS builder

RUN apk add --no-cache build-base git nodejs npm

ENV MIX_ENV=prod
WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
COPY config config

RUN mix deps.get --only prod && mix deps.compile

COPY lib lib
COPY assets assets
COPY priv priv

RUN mix assets.deploy
RUN mix compile && mix release

# ============================================
# Stage 2: Runtime (Alpine 3.22 - same as builder)
# ============================================
FROM alpine:3.22 AS runtime

RUN apk add --no-cache \
    libstdc++ \
    libgcc \
    openssl \
    ncurses-libs \
    openssh-client \
    curl \
    bash

WORKDIR /app

RUN addgroup -g 1000 ops && adduser -u 1000 -G ops -s /bin/sh -D ops

COPY --from=builder --chown=ops:ops /app/_build/prod/rel/ops_chat ./

RUN mkdir -p /app/data && chown ops:ops /app/data

ENV HOME=/app \
    MIX_ENV=prod \
    PHX_SERVER=true \
    DATABASE_PATH=/app/data/ops_chat.db \
    LANG=C.UTF-8

USER ops
EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:4000/health || exit 1

CMD ["bin/ops_chat", "start"]
