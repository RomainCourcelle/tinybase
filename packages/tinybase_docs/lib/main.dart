import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tinybase_docs/core/config.dart';
import 'package:tinybase_docs/core/docs_controller.dart';
import 'package:tinybase_docs/core/theme.dart';
import 'package:tinybase_docs/features/changelog/screen/changelog_screen.dart';
import 'package:tinybase_docs/features/example/screen/example_screen.dart';
import 'package:tinybase_docs/features/getting_started/screen/getting_started_screen.dart';
import 'package:tinybase_docs/features/home/screen/home_screen.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final _docs = DocsController();
  late final GoRouter _router = GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/getting-started',
            name: 'getting-started',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: GettingStartedScreen(),
            ),
          ),
          GoRoute(
            path: '/example',
            name: 'example',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ExampleScreen(),
            ),
          ),
          GoRoute(
            path: '/changelog',
            name: 'changelog',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ChangelogScreen(),
            ),
          ),
        ],
      ),
    ],
  );

  @override
  void dispose() {
    _docs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _docs,
      child: ListenableBuilder(
        listenable: _docs,
        builder: (context, _) {
          return MaterialApp.router(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: _docs.themeMode,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}

class _NavItem {
  final String label;
  final String path;
  final IconData icon;
  const _NavItem(this.label, this.path, this.icon);
}

const _nav = <_NavItem>[
  _NavItem('Home', '/', Icons.home_outlined),
  _NavItem('Getting started', '/getting-started', Icons.rocket_launch_outlined),
  _NavItem('Example', '/example', Icons.code_rounded),
  _NavItem('Changelog', '/changelog', Icons.history_rounded),
];

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  String _titleFor(String path) {
    for (final n in _nav) {
      if (n.path == path) return n.label;
    }
    return AppConfig.appName;
  }

  @override
  Widget build(BuildContext context) {
    final docs = context.watch<DocsController>();
    final location = GoRouterState.of(context).uri.path;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleFor(location)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ActionChip(
              label: Text('v${AppConfig.version}'),
              avatar: const Icon(Icons.tag, size: 16),
              onPressed: () => launchUrl(
                Uri.parse(AppConfig.githubReleaseUrl),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ),
          IconButton(
            tooltip: docs.themeTooltip,
            icon: Icon(docs.themeIcon),
            onPressed: docs.cycleThemeMode,
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Documentation',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'v${AppConfig.version}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.55),
                        ),
                  ),
                ],
              ),
            ),
            for (final n in _nav)
              ListTile(
                leading: Icon(n.icon),
                title: Text(n.label),
                selected: location == n.path,
                onTap: () {
                  Navigator.pop(context);
                  docs.clearSearch();
                  context.go(n.path);
                },
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('GitHub'),
              onTap: () {
                Navigator.pop(context);
                launchUrl(
                  Uri.parse(AppConfig.githubUrl),
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('pub.dev client'),
              onTap: () {
                Navigator.pop(context);
                launchUrl(
                  Uri.parse(AppConfig.pubDevClientUrl),
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
          ],
        ),
      ),
      body: child,
    );
  }
}
