import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tinybase_docs/core/docs_controller.dart';
import 'package:tinybase_docs/core/widgets/doc_guide.dart';

/// Layout doc : search + TOC sticky (desktop) + chapters filtrables.
class DocPageScaffold extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool showStyleSwitch;
  final String? styleHint;
  final List<DocChapterData> chapters;
  final List<Widget>? trailing;

  const DocPageScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.chapters,
    this.showStyleSwitch = true,
    this.styleHint,
    this.trailing,
  });

  @override
  State<DocPageScaffold> createState() => _DocPageScaffoldState();
}

class _DocPageScaffoldState extends State<DocPageScaffold> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  late final Map<String, GlobalKey> _keys;

  @override
  void initState() {
    super.initState();
    _keys = {
      for (final c in widget.chapters) c.id: GlobalKey(),
    };
    final initial = context.read<DocsController>().search;
    if (initial.isNotEmpty) _searchController.text = initial;
  }

  @override
  void didUpdateWidget(covariant DocPageScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final c in widget.chapters) {
      _keys.putIfAbsent(c.id, GlobalKey.new);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _scrollTo(String id) async {
    final ctx = _keys[id]?.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  @override
  Widget build(BuildContext context) {
    final docs = context.watch<DocsController>();
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.7);
    final filtered = widget.chapters
        .where((c) => c.matches(docs.search))
        .toList(growable: false);

    final header = <Widget>[
      Text(
        widget.title,
        style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        widget.subtitle,
        style: theme.textTheme.titleMedium?.copyWith(color: muted),
      ),
      const SizedBox(height: 20),
      TextField(
        controller: _searchController,
        onChanged: docs.setSearch,
        decoration: InputDecoration(
          hintText: 'Rechercher une étape…',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: docs.search.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Effacer',
                  onPressed: () {
                    _searchController.clear();
                    docs.clearSearch();
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
      ),
      if (widget.showStyleSwitch) ...[
        const SizedBox(height: 20),
        DocStyleSwitch(
          value: docs.style,
          onChanged: docs.setStyle,
        ),
        if (widget.styleHint != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.styleHint!,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ],
      const SizedBox(height: 16),
      _TocBar(
        chapters: filtered,
        onTap: _scrollTo,
      ),
      const SizedBox(height: 28),
    ];

    final bodyChildren = <Widget>[
      ...header,
      if (filtered.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text(
            'Aucun résultat pour « ${docs.search} ».',
            style: theme.textTheme.bodyLarge?.copyWith(color: muted),
          ),
        )
      else
        for (final c in filtered)
          DocChapter(data: c, anchorKey: _keys[c.id]),
      if (widget.trailing != null) ...widget.trailing!,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1040;
        final content = ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 64),
          children: bodyChildren,
        );

        if (!wide) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: content,
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 220,
              child: Material(
                color: theme.colorScheme.surface.withValues(alpha: 0.55),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 28, 12, 24),
                  children: [
                    Text(
                      'Sommaire',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final c in filtered)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${c.number}. ${c.title}',
                          style: theme.textTheme.bodyMedium,
                        ),
                        onTap: () => _scrollTo(c.id),
                      ),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 880),
                  child: content,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TocBar extends StatelessWidget {
  final List<DocChapterData> chapters;
  final ValueChanged<String> onTap;

  const _TocBar({required this.chapters, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (chapters.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in chapters)
          ActionChip(
            label: Text('${c.number}. ${c.title}'),
            onPressed: () => onTap(c.id),
          ),
      ],
    );
  }
}
