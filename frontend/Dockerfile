# ---- dependencies / build ----
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json ./
# If you have a lock file, copy it as well to prefer deterministic installs:
# COPY package-lock.json ./
RUN npm ci || npm install

FROM deps AS builder
COPY . .
RUN npm run build

# ---- runtime (no next CLI required) ----
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
# Copy "standalone" server output
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./.next/standalone
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/package.json ./package.json
EXPOSE 3000
CMD ["node", ".next/standalone/server.js"]
