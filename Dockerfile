# syntax=docker/dockerfile:1

# Build backend dependencies
FROM python:3.12-bookworm AS backend
WORKDIR /srv/backend
ENV PATH="${PATH}:/root/.local/bin" \
    PYTHONPATH=.
COPY backend/requirements.txt backend/pyproject.toml backend/alembic.ini.example ./
COPY backend/scripts ./scripts
COPY backend/src ./src
RUN pip install --upgrade pip \
    && pip install .'[deploy]'

# Build frontend dependencies
FROM node:lts-alpine AS frontend
WORKDIR /srv/frontend
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ .

# Final image combining backend and frontend similar to docker-compose setup
FROM python:3.12-bookworm
WORKDIR /srv
# install Node 20 for the frontend dev server
RUN apt-get update \
    && apt-get install -y ca-certificates curl gnupg \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

COPY --from=backend /srv/backend ./backend
COPY --from=frontend /srv/frontend ./frontend

ENV IS_LOCAL_DEV=yes \
    RELEASE_VERSION=localdev

EXPOSE 5000 8080
CMD ["bash", "-c", "cd backend && ./scripts/entry.sh & cd frontend && npm run dev"]
