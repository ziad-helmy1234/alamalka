# ---- build ----
FROM node:22-alpine AS build
WORKDIR /app
RUN apk add --no-cache openssl
COPY package*.json ./
RUN npm ci
COPY tsconfig.json ./
COPY prisma ./prisma
COPY src ./src
RUN npm run build && npm prune --omit=dev && npx prisma generate

# ---- runtime ----
FROM node:22-alpine
WORKDIR /app
RUN apk add --no-cache openssl tini
ENV NODE_ENV=production
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/prisma ./prisma
COPY package.json ./
USER node
EXPOSE 4000
HEALTHCHECK --interval=15s --timeout=3s CMD wget -qO- http://127.0.0.1:4000/health || exit 1
ENTRYPOINT ["/sbin/tini", "--"]
# Apply pending migrations, then start
CMD ["sh", "-c", "node node_modules/prisma/build/index.js migrate deploy && node dist/server.js"]
