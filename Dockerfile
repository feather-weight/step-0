# syntax=docker/dockerfile:1.6
# ---- deps ----
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
# Use npm ci when lockfile exists, fallback to install otherwise
RUN --mount=type=cache,target=/root/.npm npm ci || npm install

# ---- builder ----
FROM deps AS builder
WORKDIR /app
COPY . .
RUN --mount=type=cache,target=/root/.npm npm run build

# ---- runtime (no next CLI required) ----
FROM node:20-alpine AS runner
ENV NODE_ENV=production
WORKDIR /app
# Copy Next standalone output
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public
EXPOSE 3000
CMD ["node", "server.js"]
