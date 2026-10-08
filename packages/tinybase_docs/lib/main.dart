import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DocsApp());
}

enum DocStyle { provider, riverpod }

class DocsApp extends StatelessWidget {
  const DocsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TinyBase Docs',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B1220),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3DDC97),
          surface: Color(0xFF121A2B),
        ),
        textTheme: GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: const GettingStartedPage(),
    );
  }
}

class GettingStartedPage extends StatefulWidget {
  const GettingStartedPage({super.key});

  @override
  State<GettingStartedPage> createState() => _GettingStartedPageState();
}

class _GettingStartedPageState extends State<GettingStartedPage> {
  DocStyle _style = DocStyle.provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 64),
            children: [
              Text(
                'TinyBase',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Getting Started — deploy, auth, CRUD, files, realtime',
                style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 28),
              _StyleSwitch(
                value: _style,
                onChanged: (v) => setState(() => _style = v),
              ),
              const SizedBox(height: 36),
              _Section(
                step: '1',
                title: 'Deploy',
                body: 'Lance le serveur (Docker / Railway / VPS). Persiste un volume pour la DB.',
                code: r'''# Variables utiles
PORT          # injecté par le PaaS (laisse Railway le gérer)
DB_PATH       # ex. /data/tinybase.db  (sur le volume)
APP_NAME      # ex. Cerebrum Base
# JWT_SECRET  # optionnel si 1 seule instance (auto .jwt_secret)

# Local
cd packages/tinybase_server
dart run bin/server.dart''',
              ),
              _Section(
                step: '2',
                title: 'Client Flutter',
                body: 'Ajoute tinybase_client et pointe vers ton API.',
                code: r'''flutter pub add tinybase_client

import 'package:tinybase_client/tinybase_client.dart';

final client = TinyBaseClient(baseUrl: 'https://ton-api.example.com');
await client.auth.restore();''',
              ),
              _Section(
                step: '3',
                title: 'Auth',
                body: 'Génère la couche Auth depuis l’admin (Réglages → Code client), style ${_style.name}.',
                code: _style == DocStyle.provider ? _authProvider : _authRiverpod,
              ),
              _Section(
                step: '4',
                title: 'CRUD + codegen',
                body: 'Crée une collection dans l’admin, génère le code, utilise le repository.',
                code: _style == DocStyle.provider ? _crudProvider : _crudRiverpod,
              ),
              _Section(
                step: '5',
                title: 'Fichiers',
                body: 'Champ type Fichier (options max Mo / MIME). Upload multipart via le client.',
                code: r'''await client.collection('docs').create(
  {'title': 'Contrat'},
  files: {
    'attachment': FileUpload(filename: 'c.pdf', bytes: pdfBytes),
  },
);
final url = client.collection('docs').fileUrl(id, 'attachment');''',
              ),
              _Section(
                step: '6',
                title: 'Realtime SSE',
                body: 'Abonne-toi aux changements d’une collection.',
                code: r'''final sub = client.collection('notes').subscribe().listen((change) {
  print('${change.action} ${change.recordId}');
});
// sub.cancel();''',
              ),
              const SizedBox(height: 24),
              Text(
                'Profil users : ajoute des champs custom sur la collection users dans l’admin, '
                'puis register(..., fields: {...}) / updateMe({...}).',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white60),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StyleSwitch extends StatelessWidget {
  final DocStyle value;
  final ValueChanged<DocStyle> onChanged;
  const _StyleSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF121A2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Chip(
              label: 'Provider',
              selected: value == DocStyle.provider,
              onTap: () => onChanged(DocStyle.provider),
            ),
          ),
          Expanded(
            child: _Chip(
              label: 'Riverpod',
              selected: value == DocStyle.riverpod,
              onTap: () => onChanged(DocStyle.riverpod),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF3DDC97).withValues(alpha: 0.18) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? const Color(0xFF3DDC97) : Colors.white70,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String step;
  final String title;
  final String body;
  final String code;
  const _Section({
    required this.step,
    required this.title,
    required this.body,
    required this.code,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF3DDC97).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(step, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF3DDC97))),
              ),
              const SizedBox(width: 12),
              Text(title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Text(body, style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70)),
          const SizedBox(height: 12),
          _CodeBlock(code: code),
        ],
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String code;
  const _CodeBlock({required this.code});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 48, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0F1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: SelectableText(
            code.trim(),
            style: GoogleFonts.jetBrainsMono(fontSize: 12.5, height: 1.45, color: const Color(0xFFE8EEF8)),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            tooltip: 'Copier',
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code.trim()));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copié'), duration: Duration(seconds: 1)),
                );
              }
            },
          ),
        ),
      ],
    );
  }
}

const _authProvider = r'''// Admin → Réglages → Code client (Provider)
// puis dans ton app :
final auth = context.watch<AuthProvider>();
await auth.register(email: email, password: password, fields: {
  'display_name': 'Ada',
});
await auth.login(email: email, password: password);
await auth.updateMe({'display_name': 'Ada Lovelace'});''';

const _authRiverpod = r'''// Admin → Réglages → Code client (Riverpod)
// override tinyBaseClientProvider au démarrage, puis :
final auth = ref.watch(authProvider.notifier);
await auth.register(email: email, password: password, fields: {
  'display_name': 'Ada',
});
await auth.login(email: email, password: password);
await auth.updateMe({'display_name': 'Ada Lovelace'});''';

const _crudProvider = r'''// Admin → collection → Générer le code (Provider)
final notes = NotesRepository(client);
final page = await notes.list();
await notes.create({'title': 'Hello'});''';

const _crudRiverpod = r'''// Admin → collection → Générer le code (Riverpod)
// Utilise le repository généré + tes providers Riverpod
final notes = NotesRepository(ref.read(tinyBaseClientProvider));
final page = await notes.list();
await notes.create({'title': 'Hello'});''';
