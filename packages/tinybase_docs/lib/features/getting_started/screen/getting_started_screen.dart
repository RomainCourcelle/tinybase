import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tinybase_docs/core/docs_controller.dart';
import 'package:tinybase_docs/core/widgets/doc_guide.dart';
import 'package:tinybase_docs/core/widgets/doc_page_scaffold.dart';

class GettingStartedScreen extends StatelessWidget {
  const GettingStartedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final style = context.watch<DocsController>().style;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);

    return DocPageScaffold(
      title: 'Getting Started',
      subtitle: 'Deploy, auth, CRUD, files, realtime — étape par étape',
      styleHint: 'Le switch change les snippets Auth et CRUD (global à la doc).',
      chapters: [
        const DocChapterData(
          id: 'deploy',
          number: '1',
          title: 'Deploy',
          intro:
              'Lance le serveur TinyBase (Docker / Railway / VPS). Persiste un volume pour la DB.',
          steps: [
            DocStep(
              label: 'Variables d’environnement',
              where: 'Sur Railway / Docker / ton VPS',
              code: r'''PORT                 # injecté par le PaaS (laisse Railway le gérer)
DB_PATH              # ex. /data/tinybase.db  (sur le volume)
APP_NAME             # ex. Cerebrum Base
FILES_DIR            # optionnel (défaut : à côté de la DB)
MAX_FILE_SIZE        # optionnel (défaut 10 Mo)
CORS_ALLOW_ORIGIN    # si l’admin/docs est sur un autre domaine
# JWT_SECRET         # recommandé si plusieurs replicas
# AUTH_RATE_LIMIT_MAX            # défaut 20 / IP / minute
# PUBLIC_BASE_URL                # https://ton-api.example.com (liens email + meta)
# SMTP_HOST / SMTP_PORT / SMTP_USER / SMTP_PASSWORD / SMTP_FROM
# PASSWORD_RESET_URL_TEMPLATE    # optionnel, doit contenir {token}
# RETURN_PASSWORD_RESET_TOKEN    # true seulement en staging sans SMTP''',
            ),
            DocStep(
              label: 'Lancer en local',
              where: 'Terminal, à la racine du monorepo',
              code: r'''cd packages/tinybase_server
dart run bin/server.dart''',
            ),
          ],
        ),
        const DocChapterData(
          id: 'client',
          number: '2',
          title: 'Client Flutter',
          intro: 'Ajoute le package, puis initialise le client avant `runApp`.',
          steps: [
            DocStep(
              label: 'Ajouter la dépendance',
              where: 'Terminal, dans ton projet Flutter',
              code: r'''flutter pub add tinybase_client''',
            ),
            DocStep(
              label: 'Importer le package',
              where: 'En haut de `lib/main.dart`',
              code: r'''import 'package:tinybase_client/tinybase_client.dart';''',
            ),
            DocStep(
              label: 'Créer le client et restaurer la session',
              where: 'Dans `main()`, avant `runApp`',
              detail:
                  'Sur mobile les tokens vont dans le Keystore / Keychain. '
                  'Une erreur réseau au `restore()` ne déconnecte pas.',
              code: r'''Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final client = TinyBaseClient(
    baseUrl: 'https://ton-api.example.com', // URL de ton serveur TinyBase
  );
  await client.auth.restore(); // hors ligne : session locale conservée

  runApp(MyApp(client: client)); // passe le client à ton arbre de widgets
}''',
            ),
          ],
        ),
        DocChapterData(
          id: 'auth',
          number: '3',
          title: 'Auth',
          intro:
              'Génère la couche Auth depuis l’admin (Réglages → Code client), style ${style.name}.',
          steps: style == DocStyle.provider
              ? const [
                  DocStep(
                    label: 'Générer le code',
                    where: 'Admin → Réglages → Code client → Provider',
                    detail:
                        'Copie les fichiers générés dans ton app (ex. `lib/auth/`).',
                  ),
                  DocStep(
                    label: 'Brancher le provider',
                    where: 'Autour de ton `MaterialApp`',
                    code: r'''ChangeNotifierProvider(
  create: (_) => AuthProvider(client),
  child: const MyApp(),
)''',
                  ),
                  DocStep(
                    label: 'Register / login / updateMe',
                    where: 'Dans un écran (via `context`)',
                    code: r'''final auth = context.read<AuthProvider>();

await auth.register(
  email: email,
  password: password,
  fields: {'display_name': 'Ada'}, // champs custom users (optionnel)
);

await auth.login(email: email, password: password);

await auth.updateMe({'display_name': 'Ada Lovelace'});

await auth.logout(); // révoque le refresh côté serveur''',
                  ),
                ]
              : const [
                  DocStep(
                    label: 'Générer le code',
                    where: 'Admin → Réglages → Code client → Riverpod',
                    detail:
                        'Copie les fichiers générés dans ton app (ex. `lib/auth/`).',
                  ),
                  DocStep(
                    label: 'Override le client',
                    where: 'Au démarrage, dans `ProviderScope`',
                    code: r'''runApp(
  ProviderScope(
    overrides: [
      tinyBaseClientProvider.overrideWithValue(client),
    ],
    child: const MyApp(),
  ),
);''',
                  ),
                  DocStep(
                    label: 'Register / login / updateMe',
                    where: 'Dans un `ConsumerWidget` / notifier',
                    code: r'''final auth = ref.read(authProvider.notifier);

await auth.register(
  email: email,
  password: password,
  fields: {'display_name': 'Ada'}, // champs custom users (optionnel)
);

await auth.login(email: email, password: password);

await auth.updateMe({'display_name': 'Ada Lovelace'});

await auth.logout(); // révoque le refresh côté serveur''',
                  ),
                ],
        ),
        const DocChapterData(
          id: 'account',
          number: '4',
          title: 'Compte',
          intro:
              'Suppression de compte (obligatoire Play Store) et reset de mot de passe. '
              'Ces appels sont sur `client.auth`, pas dans le codegen.',
          steps: [
            DocStep(
              label: 'Supprimer le compte',
              where: 'Écran réglages, après confirmation',
              detail:
                  'Efface l’utilisateur, ses sessions, les records dont il est `owner`, et leurs fichiers. '
                  'Play Store : publie aussi l’URL `{PUBLIC_BASE_URL}/delete-account` (page web sans l’app).',
              code: r'''await client.auth.deleteAccount();
// Page web (stores) : GET /delete-account''',
            ),
            DocStep(
              label: 'Mot de passe oublié',
              where: 'Écran login',
              detail:
                  'Avec SMTP configuré, un email est envoyé (lien `/reset-password?token=`). '
                  'Sans SMTP, le token n’est renvoyé que si `RETURN_PASSWORD_RESET_TOKEN=true` (staging).',
              code: r'''await client.auth.forgotPassword(email);
// Prod : l’utilisateur ouvre le lien reçu par email
// Staging : final token = await client.auth.forgotPassword(email);
// if (token != null) await client.auth.resetPassword(...);''',
            ),
          ],
        ),
        DocChapterData(
          id: 'crud',
          number: '5',
          title: 'CRUD + codegen',
          intro:
              'Crée une collection dans l’admin, génère le code, utilise le repository.',
          steps: style == DocStyle.provider
              ? const [
                  DocStep(
                    label: 'Créer la collection',
                    where: 'Admin → Collections → Nouvelle collection',
                    detail: 'Ex. `notes` avec un champ `title` (text).',
                  ),
                  DocStep(
                    label: 'Générer le code client',
                    where: 'Admin → collection → Générer le code (Provider)',
                    detail: 'Copie le repository généré dans ton app.',
                  ),
                  DocStep(
                    label: 'Lister / créer',
                    where: 'Dans un service ou un écran',
                    detail:
                        'Un filtre `||` ne contourne pas une règle owner : '
                        'le serveur parenthèse la règle et le filtre.',
                    code: r'''final notes = NotesRepository(client);

final page = await notes.list();
await notes.create({'title': 'Hello'});''',
                  ),
                ]
              : const [
                  DocStep(
                    label: 'Créer la collection',
                    where: 'Admin → Collections → Nouvelle collection',
                    detail: 'Ex. `notes` avec un champ `title` (text).',
                  ),
                  DocStep(
                    label: 'Générer le code client',
                    where: 'Admin → collection → Générer le code (Riverpod)',
                    detail: 'Copie le repository généré dans ton app.',
                  ),
                  DocStep(
                    label: 'Lister / créer',
                    where: 'Via `ref` + le client TinyBase',
                    detail:
                        'Un filtre `||` ne contourne pas une règle owner : '
                        'le serveur parenthèse la règle et le filtre.',
                    code: r'''final notes = NotesRepository(
  ref.read(tinyBaseClientProvider),
);

final page = await notes.list();
await notes.create({'title': 'Hello'});''',
                  ),
                ],
        ),
        const DocChapterData(
          id: 'files',
          number: '6',
          title: 'Fichiers',
          intro:
              'Champ type Fichier (options max Mo / MIME, wildcards `image/*`). Upload multipart.',
          steps: [
            DocStep(
              label: 'Ajouter un champ fichier',
              where: 'Admin → schéma de la collection',
              detail:
                  'Type Fichier. Ex. max 5 Mo + `mime:image/*` + `mime:application/pdf`.',
            ),
            DocStep(
              label: 'Upload à la création',
              where: 'Dans ton app, avec des bytes (ex. file_picker)',
              code: r'''final id = await client.collection('docs').create(
  {'title': 'Contrat'},
  files: {
    'attachment': FileUpload(
      filename: 'contrat.pdf',
      bytes: pdfBytes,
    ),
  },
);''',
            ),
            DocStep(
              label: 'Télécharger (authentifié)',
              where: 'Préfère `downloadFile` — `fileUrl` n’envoie pas le Bearer',
              code: r'''final file = await client.collection('docs').downloadFile(id, 'attachment');
// file.bytes, file.contentType
// Image.memory(Uint8List.fromList(file.bytes))''',
            ),
          ],
        ),
        const DocChapterData(
          id: 'sse',
          number: '7',
          title: 'Realtime SSE',
          intro:
              'Abonne-toi aux changements. Depuis 0.3.1 : reconnect auto avec backoff.',
          steps: [
            DocStep(
              label: 'Écouter une collection',
              where: 'Dans un `initState` / provider — `cancel()` pour arrêter',
              detail:
                  '`subscribe()` se reconnecte tout seul si la connexion tombe.',
              code: r'''final sub = client.collection('notes').subscribe().listen((change) {
  print('${change.action} ${change.recordId}');
});

// Plus tard :
// await sub.cancel();''',
            ),
          ],
        ),
        const DocChapterData(
          id: 'oauth',
          number: '8',
          title: 'OAuth (optionnel)',
          intro:
              'Discord / Microsoft via navigateur ; Google / Apple via idToken natif.',
          steps: [
            DocStep(
              label: 'Ouvrir l’authorize URL',
              where: 'Après config OAuth dans l’admin',
              code: r'''final url = client.auth.authorizeUrl(
  OAuthProvider.discord,
  target: 'myapp://oauth-callback', // deep-link de ton app
);
// lance url dans le navigateur''',
            ),
            DocStep(
              label: 'Callback',
              where: 'Quand le deep-link revient',
              detail:
                  'Les tokens sont dans le fragment `#accessToken=…` (query encore acceptée).',
              code: r'''final session = await client.auth.handleOAuthCallback(callbackUri);
// session non-null → connecté''',
            ),
            DocStep(
              label: 'Google / Apple natif',
              where: 'Avec un idToken du SDK plateforme',
              code: r'''await client.auth.signInWithIdToken(
  OAuthProvider.google,
  idToken: idToken,
);''',
            ),
          ],
        ),
      ],
      trailing: [
        Text(
          'Profil users : ajoute des champs custom sur la collection users dans l’admin, '
          'puis utilise `fields:` au register et `updateMe({...})`.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted),
        ),
      ],
    );
  }
}
