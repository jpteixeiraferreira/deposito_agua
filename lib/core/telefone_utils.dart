import 'package:flutter/services.dart';

String apenasNumerosTelefone(String valor) {
  return valor.replaceAll(RegExp(r'[^0-9]'), '');
}

bool telefoneBrasileiroValido(String valor) {
  final numeros = apenasNumerosTelefone(valor);
  return numeros.length == 10 || numeros.length == 11;
}

String mascaraTelefone(String valor) {
  final numeros = apenasNumerosTelefone(valor);
  return numeros.length <= 10 ? '(##) ####-####' : '(##) #####-####';
}

String formatarTelefone(String valor) {
  final numeros = apenasNumerosTelefone(valor);

  if (numeros.length == 10) {
    return '(${numeros.substring(0, 2)}) '
        '${numeros.substring(2, 6)}-'
        '${numeros.substring(6)}';
  }

  if (numeros.length == 11) {
    return '(${numeros.substring(0, 2)}) '
        '${numeros.substring(2, 7)}-'
        '${numeros.substring(7)}';
  }

  return valor;
}

class TelefoneInputFormatter extends TextInputFormatter {
  const TelefoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final numeros = apenasNumerosTelefone(newValue.text);
    final limitado = numeros.length > 11 ? numeros.substring(0, 11) : numeros;
    final formatado = _formatarParcial(limitado);

    return TextEditingValue(
      text: formatado,
      selection: TextSelection.collapsed(offset: formatado.length),
    );
  }

  String _formatarParcial(String numeros) {
    if (numeros.length <= 2) {
      return numeros;
    }

    final ddd = numeros.substring(0, 2);
    final restante = numeros.substring(2);
    final tamanhoPrefixo = numeros.length <= 10 ? 4 : 5;

    if (restante.length <= tamanhoPrefixo) {
      return '($ddd) $restante';
    }

    return '($ddd) ${restante.substring(0, tamanhoPrefixo)}-'
        '${restante.substring(tamanhoPrefixo)}';
  }
}
