FROM caddy:builder-alpine AS builder
RUN xcaddy build \
  --with github.com/caddy-dns/cloudflare

FROM caddy:alpine AS caddy
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
