import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/config_recibo_model.dart';

class ReciboVendaPdf {
  static Future<Uint8List> gerar(
    Map<String, dynamic> venda, {
    ConfigRecibo? config,
  }) async {
    final fonteBase = await PdfGoogleFonts.openSansRegular();
    final fonteNegrito = await PdfGoogleFonts.openSansBold();
    final doc = pw.Document();
    final configRecibo = config ?? ConfigRecibo.padrao();
    final logo = await _carregarLogo(configRecibo.logoUrl);
    final data = DateTime.tryParse(venda['data_venda'].toString());
    final cliente = venda['clientes'] as Map<String, dynamic>? ?? {};
    final itens = List<Map<String, dynamic>>.from(venda['venda_itens'] ?? []);
    final pagamentos = List<Map<String, dynamic>>.from(
      venda['pagamentos'] ?? [],
    );
    final total = ((venda['total'] as num?)?.toDouble() ?? 0);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: fonteBase, bold: fonteNegrito),
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _cabecalho(venda, data, configRecibo, logo),
              _cliente(cliente, pagamentos),
              _itens(itens),
              _total(total),
              pw.Spacer(),
              pw.Divider(),
              pw.Center(
                child: pw.Text(
                  configRecibo.rodape,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static Future<pw.ImageProvider?> _carregarLogo(String logoUrl) async {
    if (logoUrl.trim().isEmpty) return null;

    try {
      return await networkImage(logoUrl.trim());
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _cabecalho(
    Map<String, dynamic> venda,
    DateTime? data,
    ConfigRecibo config,
    pw.ImageProvider? logo,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logo != null) ...[
                    pw.SizedBox(
                      width: config.logoTamanho,
                      height: config.logoTamanho,
                      child: pw.Image(logo, fit: pw.BoxFit.contain),
                    ),
                    pw.SizedBox(width: 12),
                  ],
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        pw.Text(
                          config.nomeEmpresa,
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(config.endereco, textAlign: pw.TextAlign.center),
                        pw.Text(config.cidade, textAlign: pw.TextAlign.center),
                        pw.SizedBox(height: 16),
                        pw.Text(config.email, textAlign: pw.TextAlign.center),
                        pw.Text(config.telefone, textAlign: pw.TextAlign.center),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          pw.Container(width: 1, color: PdfColors.black),
          pw.SizedBox(
            width: 170,
            child: pw.Column(
              children: [
                _boxInfo('DATA DA EMISSÃO', _data(data), 22),
                _boxInfo(
                  'NÚMERO DO PEDIDO',
                  _numeroPedido(venda['numero'] ?? venda['id']),
                  18,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _boxInfo(String titulo, String valor, double valorSize) {
    return pw.Container(
      height: 72,
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: 1)),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            titulo,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            valor,
            style: pw.TextStyle(
              fontSize: valorSize,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _cliente(
    Map<String, dynamic> cliente,
    List<Map<String, dynamic>> pagamentos,
  ) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(width: 1),
          right: pw.BorderSide(width: 1),
          bottom: pw.BorderSide(width: 1),
        ),
      ),
      padding: const pw.EdgeInsets.all(4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(child: _linhaInfo('CLIENTE', cliente['nome'])),
              pw.SizedBox(width: 12),
              pw.SizedBox(
                width: 220,
                child: _linhaInfo('CPF', cliente['cpf_cnpj']),
              ),
            ],
          ),
          _linhaInfo('ENDEREÇO', cliente['endereco']),
          pw.Row(
            children: [
              pw.Expanded(
                child: _linhaInfo('FORMA PGTO', _formasPagamento(pagamentos)),
              ),
              pw.SizedBox(width: 12),
              pw.SizedBox(width: 300, child: _linhaInfo('CONDIÇÃO PGTO', 'À VISTA')),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _linhaInfo(String label, Object? valor) {
    return pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$label: ',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.TextSpan(text: (valor ?? '').toString()),
        ],
      ),
    );
  }

  static pw.Widget _itens(List<Map<String, dynamic>> itens) {
    final linhas = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          _celulaCabecalho('CÓD.'),
          _celulaCabecalho('DESCRIÇÃO'),
          _celulaCabecalho('UNIDADE'),
          _celulaCabecalho('QTD'),
          _celulaCabecalho('VALOR UNIT.'),
          _celulaCabecalho('SUB TOTAL'),
        ],
      ),
    ];

    for (final item in itens) {
      final produto = item['produtos'] as Map<String, dynamic>? ?? {};
      final qtd = ((item['quantidade'] as num?)?.toDouble() ?? 0);
      final preco = ((item['preco_unitario'] as num?)?.toDouble() ?? 0);
      final subtotal = ((item['subtotal'] as num?)?.toDouble() ?? 0);

      linhas.add(
        pw.TableRow(
          children: [
            _celula(produto['codigo']),
            _celula(produto['descricao']),
            _celula('UN'),
            _celula(qtd.toStringAsFixed(0)),
            _celula(_moeda(preco)),
            _celula(_moeda(subtotal)),
          ],
        ),
      );
    }

    while (linhas.length < 12) {
      linhas.add(
        pw.TableRow(
          children: List.generate(6, (_) => _celula(' ', minHeight: 24)),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(width: 1),
      columnWidths: const {
        0: pw.FixedColumnWidth(45),
        1: pw.FlexColumnWidth(),
        2: pw.FixedColumnWidth(58),
        3: pw.FixedColumnWidth(42),
        4: pw.FixedColumnWidth(90),
        5: pw.FixedColumnWidth(100),
      },
      children: linhas,
    );
  }

  static pw.Widget _total(double total) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(width: 1),
          right: pw.BorderSide(width: 1),
          bottom: pw.BorderSide(width: 1),
        ),
      ),
      padding: const pw.EdgeInsets.all(6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(
            'VALOR TOTAL DA NOTA:  ',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('R\$ ${_moeda(total)}'),
        ],
      ),
    );
  }

  static pw.Widget _celulaCabecalho(String texto) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        texto,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _celula(Object? texto, {double minHeight = 20}) {
    return pw.Container(
      constraints: pw.BoxConstraints(minHeight: minHeight),
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text((texto ?? '').toString()),
    );
  }

  static String _data(DateTime? data) {
    if (data == null) return '';
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  static String _numeroPedido(Object? id) {
    final texto = (id ?? '').toString();
    final numeros = texto.replaceAll(RegExp(r'[^0-9]'), '');
    if (numeros.isEmpty) return texto;
    return numeros.length > 6
        ? numeros.substring(numeros.length - 6)
        : numeros.padLeft(6, '0');
  }

  static String _formasPagamento(List<Map<String, dynamic>> pagamentos) {
    if (pagamentos.isEmpty) return '';
    return pagamentos.map((p) => p['tipo'].toString().toUpperCase()).join(', ');
  }

  static String _moeda(double valor) {
    return valor.toStringAsFixed(2).replaceAll('.', ',');
  }
}
