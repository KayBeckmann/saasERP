# Build-Kontext ist das Repo-Root (siehe docker-compose.yml), damit das
# path-dependency-Package ../shared mit kopiert werden kann.
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /workspace

COPY shared ./shared
COPY app_kunde ./app_kunde

WORKDIR /workspace/app_kunde
RUN flutter pub get

ARG API_BASE_URL=http://localhost:8080
RUN flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL}

FROM nginx:alpine

COPY --from=build /workspace/app_kunde/build/web /usr/share/nginx/html
COPY app_kunde/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
