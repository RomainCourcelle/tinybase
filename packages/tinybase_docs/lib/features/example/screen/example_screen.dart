import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tinybase_docs/core/docs_controller.dart';
import 'package:tinybase_docs/core/widgets/code_block.dart';
import 'package:tinybase_docs/core/widgets/doc_guide.dart';
import 'package:tinybase_docs/core/widgets/doc_page_scaffold.dart';

/// Walkthrough : mini-app Notes (auth + CRUD + fichier + SSE).
class ExampleScreen extends StatelessWidget {
  const ExampleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final style = context.watch<DocsController>().style;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.7);

    return DocPageScaffold(
      title: 'Exemple : app Notes',
      subtitle:
          'Du schéma admin jusqu’à l’écran Flutter : login, liste, création, fichier, realtime.',
      styleHint: 'Les snippets Auth / wiring suivent le style global.',
      chapters: [
        const DocChapterData(
          id: 'schema',
          number: '1',
          title: 'Côté admin — schéma',
          intro:
              'On modèle une collection `notes` utilisable depuis l’app Flutter.',
          steps: [
            DocStep(
              label: 'Créer la collection',
              where: 'Admin → Collections → Nouvelle collection',
              detail: 'Nom : `notes`.',
            ),
            DocStep(
              label: 'Ajouter les champs',
              where: 'Admin → notes → Éditer le schéma',
              detail: 'Au minimum :',
              code: r'''title       text      (required)
body        text      (optionnel)
attachment  file      max 5 Mo, mime:image/*, application/pdf''',
            ),
            DocStep(
              label: 'Règles d’accès (rappel)',
              where: 'Selon ton setup admin',
              detail:
                  'Les users authentifiés doivent pouvoir list/create/update leurs notes.',
            ),
          ],
        ),
        DocChapterData(
          id: 'codegen',
          number: '2',
          title: 'Générer le code client',
          intro:
              'TinyBase génère Auth + repository `Notes` pour ${style.name}.',
          steps: style == DocStyle.provider
              ? const [
                  DocStep(
                    label: 'Auth codegen',
                    where: 'Admin → Réglages → Code client → Provider',
                    detail: 'Copie dans `lib/generated/` (ou `lib/auth/`).',
                  ),
                  DocStep(
                    label: 'Notes codegen',
                    where: 'Admin → notes → Générer le code (Provider)',
                    detail:
                        'Tu obtiens typiquement `NotesRepository` + modèles.',
                  ),
                ]
              : const [
                  DocStep(
                    label: 'Auth codegen',
                    where: 'Admin → Réglages → Code client → Riverpod',
                    detail: 'Copie dans `lib/generated/` (ou `lib/auth/`).',
                  ),
                  DocStep(
                    label: 'Notes codegen',
                    where: 'Admin → notes → Générer le code (Riverpod)',
                    detail:
                        'Tu obtiens typiquement `NotesRepository` + providers.',
                  ),
                ],
        ),
        DocChapterData(
          id: 'main',
          number: '3',
          title: 'Bootstrap `main.dart`',
          intro: 'Client TinyBase + couche Auth avant `runApp`.',
          steps: style == DocStyle.provider
              ? const [
                  DocStep(
                    label: 'Dépendances',
                    where: 'Terminal',
                    code: r'''flutter pub add tinybase_client provider''',
                  ),
                  DocStep(
                    label: 'main()',
                    where: '`lib/main.dart`',
                    code: _mainProvider,
                  ),
                ]
              : const [
                  DocStep(
                    label: 'Dépendances',
                    where: 'Terminal',
                    code: r'''flutter pub add tinybase_client flutter_riverpod''',
                  ),
                  DocStep(
                    label: 'main()',
                    where: '`lib/main.dart`',
                    code: _mainRiverpod,
                  ),
                ],
        ),
        DocChapterData(
          id: 'login',
          number: '4',
          title: 'Écran login',
          intro: 'Gate simple : si pas de session → formulaire email/password.',
          steps: style == DocStyle.provider
              ? const [
                  DocStep(
                    label: 'Gate + login',
                    where: '`lib/screens/login_screen.dart` (idée)',
                    code: _loginProvider,
                  ),
                ]
              : const [
                  DocStep(
                    label: 'Gate + login',
                    where: '`lib/screens/login_screen.dart` (idée)',
                    code: _loginRiverpod,
                  ),
                ],
        ),
        DocChapterData(
          id: 'crud',
          number: '5',
          title: 'Liste + création',
          intro: 'CRUD via le repository généré.',
          steps: style == DocStyle.provider
              ? const [
                  DocStep(
                    label: 'Charger la liste',
                    where:
                        '`NotesListScreen` — `initState` ou bouton Refresh',
                    code: r'''final client = context.read<TinyBaseClient>();
final notes = NotesRepository(client);

final page = await notes.list(); // page.items = List<Note>
setState(() => items = page.items);''',
                  ),
                  DocStep(
                    label: 'Créer une note',
                    where: 'Dialog / écran formulaire',
                    code: r'''await notes.create({
  'title': titleController.text.trim(),
  'body': bodyController.text.trim(),
});
// puis recharger list()''',
                  ),
                ]
              : const [
                  DocStep(
                    label: 'Charger la liste',
                    where: '`NotesListScreen` — via `ref`',
                    code: r'''final notes = NotesRepository(
  ref.read(tinyBaseClientProvider),
);

final page = await notes.list();
setState(() => items = page.items);''',
                  ),
                  DocStep(
                    label: 'Créer une note',
                    where: 'Dialog / écran formulaire',
                    code: r'''await notes.create({
  'title': titleController.text.trim(),
  'body': bodyController.text.trim(),
});
// puis recharger list()''',
                  ),
                ],
        ),
        const DocChapterData(
          id: 'files',
          number: '6',
          title: 'Joindre un fichier',
          intro: 'Champ `attachment` (file) à la création.',
          steps: [
            DocStep(
              label: 'Picker + upload',
              where: 'Dans le formulaire de création',
              detail: 'Nécessite `file_picker` (ou équivalent).',
              code: r'''final pick = await FilePicker.pickFiles(withData: true);
if (pick == null || pick.files.isEmpty) return;
final file = pick.files.first;

await notes.create(
  {
    'title': titleController.text.trim(),
    'body': bodyController.text.trim(),
  },
  files: {
    'attachment': FileUpload(
      filename: file.name,
      bytes: file.bytes!,
    ),
  },
);''',
            ),
            DocStep(
              label: 'Afficher / ouvrir le fichier',
              where: 'Sur une tuile de note — utilise `downloadFile` (Bearer)',
              code: r'''final file = await client
    .collection('notes')
    .downloadFile(note.id, 'attachment');
// Image.memory(Uint8List.fromList(file.bytes))
// fileUrl() = URL seule, sans Authorization''',
            ),
          ],
        ),
        DocChapterData(
          id: 'realtime',
          number: '7',
          title: 'Realtime',
          intro:
              'Quand un autre client crée/modifie une note, la liste se met à jour. '
              'Reconnect auto depuis 0.3.1.',
          steps: style == DocStyle.provider
              ? const [
                  DocStep(
                    label: 'S’abonner',
                    where: '`initState` de `NotesListScreen`',
                    detail: 'Annule la sub pour arrêter les reconnects.',
                    code: r'''late final StreamSubscription sub;

@override
void initState() {
  super.initState();
  final client = context.read<TinyBaseClient>();
  sub = client.collection('notes').subscribe().listen((_) {
    _reload(); // appelle notes.list() + setState
  });
  _reload();
}

@override
void dispose() {
  sub.cancel();
  super.dispose();
}''',
                  ),
                ]
              : const [
                  DocStep(
                    label: 'S’abonner',
                    where: '`initState` de `NotesListScreen`',
                    code: r'''late final StreamSubscription sub;

@override
void initState() {
  super.initState();
  final client = ref.read(tinyBaseClientProvider);
  sub = client.collection('notes').subscribe().listen((_) {
    _reload();
  });
  _reload();
}

@override
void dispose() {
  sub.cancel();
  super.dispose();
}''',
                  ),
                ],
        ),
      ],
      trailing: [
        const SizedBox(height: 12),
        Text(
          'Fichier complet — `lib/main.dart`',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Copie-colle pour démarrer rapidement (${style.name}).',
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
        const SizedBox(height: 12),
        CodeBlock(
          code: style == DocStyle.provider ? _fullMainProvider : _fullMainRiverpod,
        ),
        const SizedBox(height: 20),
        Text(
          'Astuce : commence sans fichier ni SSE, valide login + list/create, '
          'puis ajoute attachment et subscribe.',
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
      ],
    );
  }
}

const _mainProvider = r'''import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tinybase_client/tinybase_client.dart';
import 'generated/auth_provider.dart'; // fichier codegen
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final client = TinyBaseClient(
    baseUrl: 'https://ton-api.example.com',
  );
  await client.auth.restore();

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: client),
        ChangeNotifierProvider(create: (_) => AuthProvider(client)),
      ],
      child: const NotesApp(),
    ),
  );
}''';

const _mainRiverpod = r'''import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinybase_client/tinybase_client.dart';
import 'generated/auth.dart'; // fichier codegen
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final client = TinyBaseClient(
    baseUrl: 'https://ton-api.example.com',
  );
  await client.auth.restore();

  runApp(
    ProviderScope(
      overrides: [
        tinyBaseClientProvider.overrideWithValue(client),
      ],
      child: const NotesApp(),
    ),
  );
}''';

const _loginProvider = r'''class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  String? error;
  bool loading = false;

  Future<void> _submit() async {
    setState(() { loading = true; error = null; });
    try {
      await context.read<AuthProvider>().login(
        email: email.text.trim(),
        password: password.text,
      );
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user != null) return const NotesListScreen();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
            if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
            FilledButton(
              onPressed: loading ? null : _submit,
              child: Text(loading ? '…' : 'Login'),
            ),
          ],
        ),
      ),
    );
  }
}''';

const _loginRiverpod = r'''class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  String? error;
  bool loading = false;

  Future<void> _submit() async {
    setState(() { loading = true; error = null; });
    try {
      await ref.read(authProvider.notifier).login(
        email: email.text.trim(),
        password: password.text,
      );
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user != null) return const NotesListScreen();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
            if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
            FilledButton(
              onPressed: loading ? null : _submit,
              child: Text(loading ? '…' : 'Login'),
            ),
          ],
        ),
      ),
    );
  }
}''';

const _fullMainProvider = r'''// lib/main.dart — Notes app (Provider)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tinybase_client/tinybase_client.dart';
import 'generated/auth_provider.dart';
import 'generated/notes_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final client = TinyBaseClient(baseUrl: 'https://ton-api.example.com');
  await client.auth.restore();
  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: client),
        ChangeNotifierProvider(create: (_) => AuthProvider(client)),
      ],
      child: const NotesApp(),
    ),
  );
}

class NotesApp extends StatelessWidget {
  const NotesApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notes',
      home: Consumer<AuthProvider>(
        builder: (_, auth, __) =>
            auth.user == null ? const LoginPage() : const NotesPage(),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
            FilledButton(
              onPressed: () => context.read<AuthProvider>().login(
                email: email.text.trim(),
                password: password.text,
              ),
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});
  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  late final NotesRepository notes;
  List<dynamic> items = [];

  @override
  void initState() {
    super.initState();
    final client = context.read<TinyBaseClient>();
    notes = NotesRepository(client);
    client.collection('notes').subscribe().listen((_) => _reload());
    _reload();
  }

  Future<void> _reload() async {
    final page = await notes.list();
    if (mounted) setState(() => items = page.items);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => notes.create({'title': 'Hello', 'body': ''}).then((_) => _reload()),
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (_, i) => ListTile(title: Text('${items[i]}')),
      ),
    );
  }
}''';

const _fullMainRiverpod = r'''// lib/main.dart — Notes app (Riverpod)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tinybase_client/tinybase_client.dart';
import 'generated/auth.dart';
import 'generated/notes_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final client = TinyBaseClient(baseUrl: 'https://ton-api.example.com');
  await client.auth.restore();
  runApp(
    ProviderScope(
      overrides: [tinyBaseClientProvider.overrideWithValue(client)],
      child: const NotesApp(),
    ),
  );
}

class NotesApp extends ConsumerWidget {
  const NotesApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    return MaterialApp(
      title: 'Notes',
      home: user == null ? const LoginPage() : const NotesPage(),
    );
  }
}

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
            FilledButton(
              onPressed: () => ref.read(authProvider.notifier).login(
                email: email.text.trim(),
                password: password.text,
              ),
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}

class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});
  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  late final NotesRepository notes;
  List<dynamic> items = [];

  @override
  void initState() {
    super.initState();
    final client = ref.read(tinyBaseClientProvider);
    notes = NotesRepository(client);
    client.collection('notes').subscribe().listen((_) => _reload());
    _reload();
  }

  Future<void> _reload() async {
    final page = await notes.list();
    if (mounted) setState(() => items = page.items);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => notes.create({'title': 'Hello', 'body': ''}).then((_) => _reload()),
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (_, i) => ListTile(title: Text('${items[i]}')),
      ),
    );
  }
}''';
