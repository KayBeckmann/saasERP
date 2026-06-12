# Build-Kontext ist das Repo-Root (siehe docker-compose.yml), damit das
# path-dependency-Package ../shared mit kopiert werden kann.
FROM dart:stable

WORKDIR /workspace

COPY shared ./shared
COPY backend ./backend

WORKDIR /workspace/backend
RUN dart pub global activate dart_frog_cli
ENV PATH="$PATH:/root/.pub-cache/bin"

RUN dart pub get
RUN dart_frog build

ENV PORT=8080
EXPOSE 8080

ENTRYPOINT ["./docker-entrypoint.sh"]
