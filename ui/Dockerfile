# Base Stage
FROM node:21.1.0-alpine AS base
WORKDIR /app
COPY package.json package-lock.json ./

# Deps Stage
FROM base AS deps
RUN npm ci

# Build / Dev Stage
FROM deps AS dev
COPY . .
RUN npm run build:prod

FROM nginx:alpine
COPY --from=dev /app/dist /var/www
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 80
ENTRYPOINT ["nginx","-g","daemon off;"]
