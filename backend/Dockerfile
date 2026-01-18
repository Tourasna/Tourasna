FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .

# Build NestJS
RUN npm run build

# Verify correct output path
RUN test -f dist/src/main.js

ENV NODE_ENV=production

CMD ["node", "dist/src/main.js"]
