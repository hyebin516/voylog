# Node 24 to match local development (backend/package.json has no engines
# field, so this file is where the version is pinned).
FROM node:24-slim AS deps

WORKDIR /app

# Copied on their own so a change to source code does not reinstall every
# dependency on the next build.
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev


FROM node:24-slim

ENV NODE_ENV=production
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY package.json ./
COPY src ./src
COPY scripts ./scripts

# Profile photos land here. On a host with an ephemeral filesystem this
# directory is wiped on every deploy, so mount a volume over it or move the
# uploads to object storage -- see docs/DEPLOYMENT.md.
RUN mkdir -p uploads/profile-images

# Never run as root: a bug in an upload path should not be able to write
# anywhere outside the app.
RUN chown -R node:node /app
USER node

EXPOSE 4000

# The host's liveness probe. /health answers outside /api/v1 and outside the
# rate limiter, so a probe can run as often as it likes.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s \
  CMD node -e "fetch('http://127.0.0.1:4000/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "src/server.js"]
