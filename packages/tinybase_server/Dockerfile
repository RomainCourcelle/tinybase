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
# tinybase_admin dépend de tinybase_shared via `path: ../tinybase_shared`
# (voir pubspec.yaml) — sans copier aussi ce dossier ici, `flutter pub get`
# échoue avec "package tinybase_shared at ../tinybase_shared" introuvable,
# le chemin relatif ne pointant vers rien dans ce stage de build isolé.
COPY packages/tinybase_shared packages/tinybase_shared
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
# tinybase_server dépend AUSSI de tinybase_codegen via `path: ../tinybase_codegen`
# (voir pubspec.yaml, utilisé par settings_routes.dart pour l'auth codegen) —
# même bug que pour tinybase_shared côté admin-build ci-dessus : oublié ici,
# `dart pub get` aurait échoué juste après le fix de tinybase_admin.
COPY packages/tinybase_codegen packages/tinybase_codegen
COPY packages/tinybase_server packages/tinybase_server
WORKDIR /repo/packages/tinybase_server
RUN dart pub get
# PAS `dart compile exe` : sqlite3/sqlite3_connection_pool (dépendances de
# sqlite_async) utilisent désormais les "build hooks" (assets natifs) pour
# fournir leur bibliothèque SQLite native — `dart compile exe` ne sait pas
# les intégrer ("does not support build hooks, use 'dart build' instead",
# erreur obtenue en essayant sur Railway) et ne compile QUE le binaire, sans
# la lib native dont il a besoin au runtime de toute façon. `dart build cli`
# est le remplaçant officiel : il produit un dossier `bundle/` avec le
# binaire dans `bin/` et la(les) bibliothèque(s) native(s) dans `lib/`, côte
# à côte — voir stage-2 plus bas qui copie tout ce dossier tel quel.
RUN dart build cli --target=bin/server.dart --output=dist

# --- Stage 3 : image runtime -------------------------------------------------
# `debian-slim` (pas `scratch`) car dart compile exe est lié dynamiquement à
# la libc.
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
# `dist/bundle/` = { bin/server, lib/*.so } — copiés ensemble et gardés
# côte à côte (bin/ et lib/ frères sous /app) car le binaire résout sa(ses)
# bibliothèque(s) native(s) via un chemin relatif à cette structure.
COPY --from=server-build /repo/packages/tinybase_server/dist/bundle /app
COPY --from=admin-build /repo/packages/tinybase_admin/build/web /app/public
EXPOSE 8090
CMD ["/app/bin/server"]
