/// Dérive le nom d'affichage de l'instance (sidebar / écran de connexion).
///
/// Priorité :
/// 1. [configuredName] (`APP_NAME` via `/api/meta`)
/// 2. Premier label DNS du host de [serverUrl] + suffixe ` Base`
/// 3. `TinyBase` pour localhost / IP / URL invalide
String instanceDisplayName({String? configuredName, String? serverUrl}) {
  final configured = configuredName?.trim();
  if (configured != null && configured.isNotEmpty) return configured;

  if (serverUrl == null || serverUrl.trim().isEmpty) return 'TinyBase';

  Uri? uri;
  try {
    uri = Uri.parse(serverUrl.trim());
  } catch (_) {
    return 'TinyBase';
  }

  var host = uri.host;
  if (host.isEmpty) {
    // "cerebrum.up.railway.app" sans schéma
    try {
      uri = Uri.parse('https://${serverUrl.trim()}');
      host = uri.host;
    } catch (_) {
      return 'TinyBase';
    }
  }

  if (host == 'localhost' || host == '127.0.0.1' || _isIp(host)) {
    return 'TinyBase';
  }

  final labels = host.split('.').where((l) => l.isNotEmpty).toList();
  if (labels.isEmpty) return 'TinyBase';
  var label = labels.first;
  if (label.toLowerCase() == 'www' && labels.length > 1) {
    label = labels[1];
  }

  final titled = _titleCase(label);
  return '$titled Base';
}

bool _isIp(String host) {
  final parts = host.split('.');
  if (parts.length == 4 && parts.every((p) => int.tryParse(p) != null)) return true;
  return host.contains(':'); // IPv6
}

String _titleCase(String raw) {
  if (raw.isEmpty) return raw;
  final lower = raw.toLowerCase();
  return '${lower[0].toUpperCase()}${lower.substring(1)}';
}
