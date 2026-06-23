FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci

FROM node:20-alpine AS build
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=8080
RUN apk add --no-cache curl && \
    curl -fsSL -o cloud-sql-proxy \
      https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.14.1/cloud-sql-proxy.linux.amd64 && \
    chmod +x cloud-sql-proxy
COPY --from=build /app/.next/standalone ./
COPY --from=build /app/.next/static ./.next/static
COPY --from=build /app/database ./database
EXPOSE 8080
CMD ["sh", "-c", "./cloud-sql-proxy \"${CLOUD_SQL_CONNECTION_NAME}\" --port=5432 & node server.js"]
