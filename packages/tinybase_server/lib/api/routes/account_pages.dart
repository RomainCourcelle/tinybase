import 'package:shelf/shelf.dart';

import '../../core/config.dart';

/// Page web Play Store : suppression de compte (password OU lien email).
Response deleteAccountPage(Request request) {
  final app = _esc(Config.appName ?? 'TinyBase');
  final token = request.url.queryParameters['token'] ?? '';
  final html = token.isEmpty ? _deleteAccountHtml(app) : _confirmDeleteHtml(app, token);
  return Response.ok(
    html,
    headers: {'content-type': 'text/html; charset=utf-8'},
  );
}

/// Page web : formulaire de nouveau mot de passe (`?token=`).
Response resetPasswordPage(Request request) {
  final app = _esc(Config.appName ?? 'TinyBase');
  final token = request.url.queryParameters['token'] ?? '';
  return Response.ok(
    _resetPasswordHtml(app, token),
    headers: {'content-type': 'text/html; charset=utf-8'},
  );
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _shell(String app, String title, String body) => '''
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>$title — $app</title>
  <style>
    :root { color-scheme: light dark; }
    body { font-family: system-ui, sans-serif; max-width: 420px; margin: 48px auto; padding: 0 16px; line-height: 1.45; }
    h1 { font-size: 1.35rem; margin-bottom: 8px; }
    p.muted { opacity: .7; font-size: .95rem; }
    label { display: block; margin: 14px 0 4px; font-size: .9rem; }
    input { width: 100%; box-sizing: border-box; padding: 10px 12px; border-radius: 8px; border: 1px solid #8884; font-size: 1rem; }
    button { margin-top: 18px; width: 100%; padding: 12px; border: 0; border-radius: 8px; background: #1b7f4e; color: #fff; font-weight: 600; font-size: 1rem; cursor: pointer; }
    button.secondary { background: transparent; color: inherit; border: 1px solid #8886; margin-top: 10px; }
    button:disabled { opacity: .6; cursor: default; }
    .msg { margin-top: 16px; padding: 12px; border-radius: 8px; background: #8882; }
    .err { background: #c6282818; color: #c62828; }
    .ok { background: #1b7f4e18; color: #1b7f4e; }
    hr { border: 0; border-top: 1px solid #8884; margin: 28px 0; }
    h2 { font-size: 1.05rem; margin: 0 0 6px; }
  </style>
</head>
<body>
$body
</body>
</html>
''';

String _deleteAccountHtml(String app) => _shell(app, 'Supprimer mon compte', '''
  <h1>Supprimer mon compte</h1>
  <p class="muted">$app — cette action est définitive : ton compte, tes sessions et tes données personnelles associées seront effacés.</p>

  <h2>Compte email / mot de passe</h2>
  <form id="f-pass">
    <label for="email">Email</label>
    <input id="email" name="email" type="email" required autocomplete="username"/>
    <label for="password">Mot de passe</label>
    <input id="password" name="password" type="password" required autocomplete="current-password"/>
    <button type="submit">Supprimer définitivement</button>
  </form>

  <hr/>

  <h2>Compte Google / Apple / Discord / Microsoft</h2>
  <p class="muted">Pas de mot de passe ? On t’envoie un lien de confirmation par email.</p>
  <form id="f-link">
    <label for="email2">Email du compte</label>
    <input id="email2" name="email" type="email" required autocomplete="username"/>
    <button type="submit" class="secondary">Recevoir le lien de suppression</button>
  </form>

  <div id="msg" class="msg" hidden></div>
  <script>
    const msg = document.getElementById('msg');
    function show(ok, text) {
      msg.className = 'msg ' + (ok ? 'ok' : 'err');
      msg.textContent = text;
      msg.hidden = false;
    }
    document.getElementById('f-pass').addEventListener('submit', async (e) => {
      e.preventDefault();
      msg.hidden = true;
      const btn = e.target.querySelector('button');
      btn.disabled = true;
      try {
        const res = await fetch('/api/auth/delete-account', {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({
            email: document.getElementById('email').value.trim(),
            password: document.getElementById('password').value,
          }),
        });
        const data = await res.json().catch(() => ({}));
        if (!res.ok) throw new Error(data.error || ('Erreur ' + res.status));
        e.target.hidden = true;
        document.getElementById('f-link').hidden = true;
        show(true, 'Compte supprimé. Tu peux fermer cette page.');
      } catch (err) {
        show(false, err.message || String(err));
        btn.disabled = false;
      }
    });
    document.getElementById('f-link').addEventListener('submit', async (e) => {
      e.preventDefault();
      msg.hidden = true;
      const btn = e.target.querySelector('button');
      btn.disabled = true;
      try {
        const res = await fetch('/api/auth/request-delete-account', {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({
            email: document.getElementById('email2').value.trim(),
          }),
        });
        const data = await res.json().catch(() => ({}));
        if (!res.ok) throw new Error(data.error || ('Erreur ' + res.status));
        show(true, 'Si un compte existe pour cet email, un lien de confirmation a été envoyé. Vérifie ta boîte mail.');
      } catch (err) {
        show(false, err.message || String(err));
      } finally {
        btn.disabled = false;
      }
    });
  </script>
''');

String _confirmDeleteHtml(String app, String token) => _shell(app, 'Confirmer la suppression', '''
  <h1>Confirmer la suppression</h1>
  <p class="muted">$app — clique pour supprimer définitivement ton compte.</p>
  <button id="confirm" type="button">Supprimer définitivement mon compte</button>
  <div id="msg" class="msg" hidden></div>
  <script>
    const token = ${jsonEncodeJs(token)};
    const msg = document.getElementById('msg');
    const btn = document.getElementById('confirm');
    btn.addEventListener('click', async () => {
      btn.disabled = true;
      msg.hidden = true;
      try {
        const res = await fetch('/api/auth/confirm-delete-account', {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ token }),
        });
        const data = await res.json().catch(() => ({}));
        if (!res.ok) throw new Error(data.error || ('Erreur ' + res.status));
        btn.hidden = true;
        msg.className = 'msg ok';
        msg.textContent = 'Compte supprimé. Tu peux fermer cette page.';
        msg.hidden = false;
      } catch (err) {
        msg.className = 'msg err';
        msg.textContent = err.message || String(err);
        msg.hidden = false;
        btn.disabled = false;
      }
    });
  </script>
''');

/// Encode a Dart string as a JS string literal.
String jsonEncodeJs(String s) {
  final escaped = s
      .replaceAll('\\', '\\\\')
      .replaceAll("'", "\\'")
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '\\r')
      .replaceAll('<', '\\u003c');
  return "'$escaped'";
}

String _resetPasswordHtml(String app, String token) {
  final safeToken = _esc(token);
  return _shell(app, 'Nouveau mot de passe', '''
  <h1>Nouveau mot de passe</h1>
  <p class="muted">$app</p>
  <form id="f">
    <input type="hidden" id="token" value="$safeToken"/>
    <label for="password">Nouveau mot de passe (8 caractères min.)</label>
    <input id="password" name="password" type="password" required minlength="8" autocomplete="new-password"/>
    <button type="submit">Enregistrer</button>
  </form>
  <div id="msg" class="msg" hidden></div>
  <script>
    const f = document.getElementById('f');
    const msg = document.getElementById('msg');
    f.addEventListener('submit', async (e) => {
      e.preventDefault();
      msg.hidden = true;
      const btn = f.querySelector('button');
      btn.disabled = true;
      try {
        const res = await fetch('/api/auth/reset-password', {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({
            token: document.getElementById('token').value,
            password: document.getElementById('password').value,
          }),
        });
        const data = await res.json().catch(() => ({}));
        if (!res.ok) throw new Error(data.error || ('Erreur ' + res.status));
        f.hidden = true;
        msg.className = 'msg ok';
        msg.textContent = 'Mot de passe mis à jour. Tu peux te connecter.';
        msg.hidden = false;
      } catch (err) {
        msg.className = 'msg err';
        msg.textContent = err.message || String(err);
        msg.hidden = false;
        btn.disabled = false;
      }
    });
  </script>
''');
}
