import 'package:deposito_agua/core/telefone_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('telefone utils', () {
    test('aceita telefone fixo com DDD e 8 digitos', () {
      expect(telefoneBrasileiroValido('(22) 1234-5678'), isTrue);
      expect(formatarTelefone('2212345678'), '(22) 1234-5678');
    });

    test('aceita celular com DDD e 9 digitos', () {
      expect(telefoneBrasileiroValido('(22) 91234-5678'), isTrue);
      expect(formatarTelefone('22912345678'), '(22) 91234-5678');
    });

    test('rejeita telefones sem 10 ou 11 digitos', () {
      expect(telefoneBrasileiroValido('221234567'), isFalse);
      expect(telefoneBrasileiroValido('229123456789'), isFalse);
    });

    test('formatter permite DDD mais 9 digitos', () {
      const formatter = TelefoneInputFormatter();

      final result = formatter.formatEditUpdate(
        const TextEditingValue(),
        const TextEditingValue(text: '22912345678'),
      );

      expect(result.text, '(22) 91234-5678');
    });
  });
}
