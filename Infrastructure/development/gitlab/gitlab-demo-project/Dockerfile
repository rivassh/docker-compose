# =============================================================================
# Demo Application Dockerfile
# =============================================================================
# This is a multi-stage, production-quality Dockerfile used by the
# GitLab CI/CD pipeline defined in .gitlab-ci.yml.
#
# Build context (assumes these files exist in the project root):
#   - index.html       – static demo page
#   - health.json      – endpoint for healthcheck
#   - requirements.txt – (optional) Python deps for a tiny API
#
# The image is built with Docker-in-Docker (DinD) and pushed to the
# local registry: gitlab.local:5050/<project-path>:<tag>
# =============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# Stage 1: Build a small static site using Alpine + a tiny Python helper
# ─────────────────────────────────────────────────────────────────────────────
FROM alpine:3.19 AS builder

# Install basic tools for asset preparation
RUN apk add --no-cache bash curl

WORKDIR /build

# Copy any pre-existing static assets
# (If they don't exist, the `|| true` lets the build continue.)
COPY index.html* ./
COPY health.json* ./
COPY requirements.txt* ./

# Generate fallback content so the image builds even without source files
RUN if [ ! -f index.html ]; then \
      echo '<!DOCTYPE html><html><body> \
            <h1>GitLab Local Demo</h1> \
            <p>Built by <code>.gitlab-ci.yml</code> at $(date -u +%Y-%m-%dT%H:%M:%SZ)</p> \
            </body></html>' > index.html; \
    fi
RUN if [ ! -f health.json ]; then \
      echo '{"status":"ok","service":"gitlab-demo","version":"1.0.0"}' > health.json; \
    fi

# ─────────────────────────────────────────────────────────────────────────────
# Stage 2: Runtime image – minimal nginx:alpine serving the built assets
# ─────────────────────────────────────────────────────────────────────────────
FROM nginx:1.27-alpine

# Labels useful when inspecting the image in the local registry
LABEL maintainer="local-dev@example.com" \
      org.opencontainers.image.title="gitlab-demo" \
      org.opencontainers.image.source="https://gitlab.local/root/gitlab-demo-project" \
      org.opencontainers.image.description="Demo app built by the GitLab CI pipeline" \
      org.opencontainers.image.licenses="MIT"

# Copy the prepared static assets from the builder stage
COPY --from=builder /build/index.html  /usr/share/nginx/html/index.html
COPY --from=builder /build/health.json /usr/share/nginx/html/health.json

# Add a custom nginx config that exposes /health on port 80
RUN { \
      echo 'server {'; \
      echo '  listen 80;'; \
      echo '  server_name _;'; \
      echo '  root /usr/share/nginx/html;'; \
      echo '  index index.html;'; \
      echo '  location /health {'; \
      echo '    add_header Content-Type application/json;'; \
      echo '    try_files /health.json =404;'; \
      echo '  }'; \
      echo '  location / {'; \
      echo '    try_files $uri $uri/ =404;'; \
      echo '  }'; \
      echo '}'; \
    } > /etc/nginx/conf.d/default.conf

# Expose HTTP
EXPOSE 80

# Container-level healthcheck (works for `docker ps` and orchestrators)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost/health >/dev/null 2>&1 || exit 1

# Default nginx entrypoint
CMD ["nginx", "-g", "daemon off;"]
