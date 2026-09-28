# Ce Dockerfile est pensé pour être buildé avec pour contexte la RACINE du
# monorepo (tinybase_core/), pas ce dossier — c'est nécessaire pour que la
# dépendance `path: ../tinybase_shared` de tinybase_server, ainsi que
# tinybase_admin (buildé en Flutter Web et servi statiquement par le
# serveur), soient visibles pendant le build. Sur Railway : régler le
# service sur build context = racine du repo, Dockerfile Path =
# packages/tinybase_server/Dockerfile.

# --- Stage 1 : build de l'admin Flutter Web ---------------------------------
FROM ghcr.io/cirruslabs/flutter:stable AS admin-build
WORKDIR /repo
COPY packages/tinybase_admin packages/tinybase_admin
WORKDIR /repo/packages/tinybase_admin
RUN flutter pub get
RUN flutter build web --release

# --- Stage 2 : compile le binaire natif du serveur --------------------------
# Railway build ce Dockerfile sur ses propres runners Linux, donc pas de
# souci de cross-compilation ici même si le poste de dev est Windows.
FROM dart:stable AS server-build
WORKDIR /repo
COPY packages/tinybase_shared packages/tinybase_shared
COPY packages/tinybase_server packages/tinybase_server
WORKDIR /repo/packages/tinybase_server
RUN dart pub get
RUN dart compile exe bin/server.dart -o bin/server

# --- Stage 3 : image runtime -------------------------------------------------
# `debian-slim` (pas `scratch`) car dart compile exe est lié dynamiquement à
# la libc.
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=server-build /repo/packages/tinybase_server/bin/server /app/server
COPY --from=admin-build /repo/packages/tinybase_admin/build/web /app/public
EXPOSE 8090
CMD ["/app/server"]
