# Build context = racine du monorepo.
# Railway : Dockerfile Path = packages/tinybase_docs/Dockerfile
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /repo
COPY packages/tinybase_docs packages/tinybase_docs
WORKDIR /repo/packages/tinybase_docs
RUN flutter pub get
# Pas de service worker : une doc web n'a pas besoin d'offline PWA, et le SW
# gardait d'anciens builds (v0.3.1) malgré les redeploys.
RUN flutter build web --release --pwa-strategy=none

FROM nginx:alpine
COPY packages/tinybase_docs/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /repo/packages/tinybase_docs/build/web /usr/share/nginx/html
# Railway injecte PORT — on remplace le listen 80 au démarrage.
CMD sh -c "sed -i 's/listen 80;/listen ${PORT:-80};/' /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"
