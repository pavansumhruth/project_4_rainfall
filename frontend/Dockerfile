FROM node:18-alpine
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install --no-audit --no-fund
COPY . .
EXPOSE 5173
ENV PORT=5173
CMD ["sh","-lc","npm run dev -- --host 0.0.0.0 --port ${PORT:-5173}"]
