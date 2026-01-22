# ============================================
# Stage 1: Build
# ============================================
FROM node:18-alpine AS builder

# Argumento de build para personalización
ARG USERNAME=demo
ENV VITE_USERNAME=${USERNAME}

# Establecer directorio de trabajo
WORKDIR /app

# Crear directorios vacíos si no existen
RUN mkdir -p src public

# Copiar archivos de dependencias
COPY package.json ./

# Instalar dependencias (sin package-lock.json)
RUN npm install --legacy-peer-deps

# Copiar archivos de configuración
COPY vite.config.js ./
COPY tailwind.config.js ./
COPY postcss.config.js ./
COPY index.html ./

# Copiar código fuente
COPY src/ ./src/


COPY public/ ./public/

# Build de producción
RUN npm run build

EXPOSE 3000

CMD [ "npm", "run", "preview" ]