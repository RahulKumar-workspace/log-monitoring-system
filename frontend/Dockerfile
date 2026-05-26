# Build Stage
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files and install dependencies
COPY package.json package-lock.json* ./
RUN npm ci

# Copy source code and build app
COPY . .
# Pass build-time environment variables if needed
# ARG VITE_API_BASE_URL
# ENV VITE_API_BASE_URL=$VITE_API_BASE_URL
RUN npm run build

# Runner Stage
FROM nginx:alpine

# Copy custom Nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy build files from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
