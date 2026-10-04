import 'package:test/test.dart';
import 'package:tinybase_codegen/tinybase_codegen.dart';
import 'package:tinybase_shared/tinybase_shared.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1);
  final collection = CollectionDefinition(
    id: 'col_password',
    name: 'password',
    type: CollectionType.base,
    fields: [
      FieldDefinition(name: 'platform', type: FieldType.text, required: true),
      FieldDefinition(name: 'username', type: FieldType.text, required: true),
    ],
    created: now,
    updated: now,
  );

  group('StateManagementStyle.parse', () {
    test('défaut et provider', () {
      expect(StateManagementStyle.parse(null), StateManagementStyle.provider);
      expect(StateManagementStyle.parse(''), StateManagementStyle.provider);
      expect(StateManagementStyle.parse('provider'), StateManagementStyle.provider);
      expect(StateManagementStyle.parse('PROVIDER'), StateManagementStyle.provider);
    });

    test('riverpod', () {
      expect(StateManagementStyle.parse('riverpod'), StateManagementStyle.riverpod);
    });

    test('inconnu', () {
      expect(() => StateManagementStyle.parse('bloc'), throwsFormatException);
    });
  });

  group('CodegenService', () {
    test('provider génère ChangeNotifier', () {
      final files = CodegenService.generate(collection);
      final provider = files.firstWhere((f) => f.path.endsWith('_provider.dart')).content;
      expect(provider, contains('ChangeNotifier'));
      expect(provider, isNot(contains('@riverpod')));
    });

    test('riverpod génère notifier annoté', () {
      final files = CodegenService.generate(
        collection,
        style: StateManagementStyle.riverpod,
      );
      final provider = files.firstWhere((f) => f.path.endsWith('_provider.dart')).content;
      expect(provider, contains('@riverpod'));
      expect(provider, contains('PasswordNotifier'));
      expect(provider, contains("part 'password_provider.g.dart';"));
      expect(provider, contains('auth_provider.dart'));
    });
  });

  group('AuthCodegenService', () {
    test('provider', () {
      final files = AuthCodegenService.generate();
      expect(files.single.content, contains('class AuthProvider extends ChangeNotifier'));
    });

    test('riverpod', () {
      final files = AuthCodegenService.generate(style: StateManagementStyle.riverpod);
      final content = files.single.content;
      expect(content, contains('tinyBaseClient'));
      expect(content, contains('@Riverpod(keepAlive: true)'));
      expect(content, contains('class Auth extends'));
    });
  });
}
