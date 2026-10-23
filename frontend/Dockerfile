# Etap 1: Budowanie aplikacji (Node.js)
FROM node:18-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# Etap 2: Serwer produkcyjny (Nginx)
FROM nginx:stable-alpine
# Vite domyślnie buduje pliki do folderu /dist
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]git add .