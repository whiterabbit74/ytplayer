FROM mcr.microsoft.com/playwright:v1.50.0-noble

RUN apt-get update && apt-get install -y --no-install-recommends socat && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY index.js entrypoint.sh ./
RUN chmod +x entrypoint.sh

RUN mkdir -p /data

CMD ["./entrypoint.sh"]
