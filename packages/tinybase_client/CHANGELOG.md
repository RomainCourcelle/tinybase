## 0.4.0

- `SecureTokenStore` (Keystore / Keychain) as the default on mobile.
- `restore()` keeps the local session on network errors and timeouts.
- Single in-flight refresh (lock) so concurrent 401s do not rotate twice.
- JSON and multipart requests time out (30s by default).
- `logout()` revokes the refresh token on the server.
- `deleteAccount()`, `forgotPassword()`, `resetPassword()`.

## 0.3.2

- Point `documentation` to the hosted Getting Started site.

## 0.3.1

- `TinyBaseCollection.downloadFile` (Bearer + refresh retry).
- SSE `subscribe()` auto-reconnect with backoff.
- OAuth callback: parse tokens from URI fragment (and query fallback).

## 0.3.0

- `register(..., fields: {...})` for custom `users` profile fields.
- `updateMe(fields)` via `PATCH /api/auth/me`.
- `TinyBaseUser.fields` holds custom profile data from `/me`.

## 0.2.0

- File uploads via multipart on `create` / `update` (`FileUpload`).
- `TinyBaseCollection.fileUrl` for download URLs.
- Realtime SSE: `TinyBaseCollection.subscribe()` → `Stream<RecordChange>`.
- `TinyBaseClient.meta()` for public instance metadata (`appName`).

## 0.1.1

- Shorten pubspec description (pub points).
- Add dartdoc comments on the public API.
- Add `example/main.dart`.

## 0.1.0

- Première publication sur pub.dev.
- Auth email/password + OAuth (Discord/Microsoft browser, Google/Apple native).
- Refresh JWT automatique sur 401.
- CRUD générique sur les collections.
- `SharedPreferencesTokenStore` + `InMemoryTokenStore`.
