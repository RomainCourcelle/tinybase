import 'package:flutter/material.dart';
import 'package:tinybase_docs/core/widgets/doc_guide.dart';

class DocsController extends ChangeNotifier {
  DocStyle _style = DocStyle.provider;
  ThemeMode _themeMode = ThemeMode.system;
  String _search = '';

  DocStyle get style => _style;
  ThemeMode get themeMode => _themeMode;
  String get search => _search;

  void setStyle(DocStyle value) {
    if (_style == value) return;
    _style = value;
    notifyListeners();
  }

  void setThemeMode(ThemeMode value) {
    if (_themeMode == value) return;
    _themeMode = value;
    notifyListeners();
  }

  void cycleThemeMode() {
    setThemeMode(switch (_themeMode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    });
  }

  IconData get themeIcon => switch (_themeMode) {
        ThemeMode.system => Icons.brightness_auto_rounded,
        ThemeMode.light => Icons.light_mode_rounded,
        ThemeMode.dark => Icons.dark_mode_rounded,
      };

  String get themeTooltip => switch (_themeMode) {
        ThemeMode.system => 'Thème : système',
        ThemeMode.light => 'Thème : clair',
        ThemeMode.dark => 'Thème : sombre',
      };

  void setSearch(String value) {
    if (_search == value) return;
    _search = value;
    notifyListeners();
  }

  void clearSearch() => setSearch('');
}
