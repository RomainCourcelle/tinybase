import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class CodeBlock extends StatelessWidget {
  final String code;

  const CodeBlock({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 48, 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.5)),
          ),
          child: SelectableText(
            code.trim(),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12.5,
              height: 1.45,
              color: const Color(0xFFE8EEF8),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton(
            tooltip: 'Copier',
            icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.white70),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code.trim()));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copié'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }
}
