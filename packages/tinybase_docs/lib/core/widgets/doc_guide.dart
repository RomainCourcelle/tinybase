import 'package:flutter/material.dart';
import 'package:tinybase_docs/core/widgets/code_block.dart';

enum DocStyle { provider, riverpod }

class DocStep {
  final String label;
  final String? where;
  final String? detail;
  final String? code;

  const DocStep({
    required this.label,
    this.where,
    this.detail,
    this.code,
  });

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return label.toLowerCase().contains(q) ||
        (where?.toLowerCase().contains(q) ?? false) ||
        (detail?.toLowerCase().contains(q) ?? false) ||
        (code?.toLowerCase().contains(q) ?? false);
  }
}

class DocChapterData {
  final String id;
  final String number;
  final String title;
  final String intro;
  final List<DocStep> steps;

  const DocChapterData({
    required this.id,
    required this.number,
    required this.title,
    required this.intro,
    required this.steps,
  });

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (title.toLowerCase().contains(q) || intro.toLowerCase().contains(q)) {
      return true;
    }
    return steps.any((s) => s.matches(q));
  }
}

class DocChapter extends StatelessWidget {
  final DocChapterData data;
  final GlobalKey? anchorKey;

  const DocChapter({
    super.key,
    required this.data,
    this.anchorKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      key: anchorKey,
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  data.number,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  data.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            data.intro,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < data.steps.length; i++) ...[
            _DocStepTile(index: i + 1, step: data.steps[i]),
            if (i < data.steps.length - 1) const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

class _DocStepTile extends StatelessWidget {
  final int index;
  final DocStep step;

  const _DocStepTile({required this.index, required this.step});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.65);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Step $index — ${step.label}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (step.where != null) ...[
          const SizedBox(height: 4),
          Text(
            'Où : ${step.where}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (step.detail != null) ...[
          const SizedBox(height: 6),
          Text(
            step.detail!,
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
        ],
        if (step.code != null) ...[
          const SizedBox(height: 10),
          CodeBlock(code: step.code!),
        ],
      ],
    );
  }
}

class DocStyleSwitch extends StatelessWidget {
  final DocStyle value;
  final ValueChanged<DocStyle> onChanged;

  const DocStyleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outline),
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

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: 0.15)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected
                    ? scheme.primary
                    : scheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
