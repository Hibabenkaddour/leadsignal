FROM node:22-bookworm-slim
WORKDIR /app
COPY --chown=node:node . /app
USER node
ENV NODE_ENV=production PORT=3000
EXPOSE 3000
CMD ["node", "server.js"]
