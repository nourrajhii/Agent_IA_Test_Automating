# ── Étape 1 : build Vite ────────────────────────────────────────────────
FROM node:20-alpine AS build
WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .

# Injecte l'URL du backend au moment du build (lue par App.jsx via
# import.meta.env.VITE_API_URL — voir le correctif App.jsx fourni à côté).
ARG VITE_API_URL=http://localhost:8000
ENV VITE_API_URL=$VITE_API_URL

RUN npm run build

# ── Étape 2 : servir les fichiers statiques avec nginx ─────────────────
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]