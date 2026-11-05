# syntax=docker/dockerfile:1

# --- Frontend: build the dashboard's static assets -------------------------
FROM node:22-slim AS frontend-builder
WORKDIR /frontend
COPY ulysses/dashboard/frontend/package.json ulysses/dashboard/frontend/package-lock.json ./
RUN npm ci
COPY ulysses/dashboard/frontend/ ./
RUN npm run build

# --- Runtime: the agent itself ----------------------------------------------
FROM python:3.14-slim AS runtime
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

WORKDIR /app

# Install dependencies before copying source so this layer is cached across
# source-only changes (uv's documented Docker pattern).
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project

COPY README.md ./
COPY ulysses/ ulysses/
COPY --from=frontend-builder /frontend/dist ulysses/dashboard/frontend/dist
RUN uv sync --frozen --no-dev

# Runtime data (SQLite DB, logs) lives here -- mount a volume at /data so it
# survives container recreation. See `Settings.ulysses_home` in
# ulysses/config/settings.py, overridden via ULYSSES_ULYSSES_HOME below.
ENV ULYSSES_ULYSSES_HOME=/data
RUN useradd --create-home --uid 1000 ulysses \
    && mkdir -p /data \
    && chown -R ulysses:ulysses /app /data
USER ulysses

ENV PATH="/app/.venv/bin:${PATH}"
VOLUME ["/data"]
EXPOSE 8765

ENTRYPOINT ["ulysses"]
CMD ["start"]
