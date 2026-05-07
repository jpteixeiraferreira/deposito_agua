import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class RelatorioVendasPdf {
  static Future<Uint8List> gerar({
    required DateTime inicio,
    required DateTime fim,
    required List<Map<String, dynamic>> vendas,
    required Map<String, double> totaisPorPagamento,
    required Map<String, Map<String, double>> resumoProdutos,
    required bool detalhado,
  }) async {
    final fonteBase = await PdfGoogleFonts.openSansRegular();
    final fonteNegrito = await PdfGoogleFonts.openSansBold();
    final doc = pw.Document();
    final vendasFinalizadas = vendas
        .where((venda) => (venda['status'] ?? 'finalizada') != 'cancelada')
        .toList();
    final total = vendasFinalizadas.fold<double>(
      0,
      (soma, venda) => soma + ((venda['total'] as num?)?.toDouble() ?? 0),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: fonteBase, bold: fonteNegrito),
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            'Relatorio de vendas',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Periodo: ${_data(inicio)} ate ${_data(fim)}'),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              _cardResumo('Total vendido', _moeda(total)),
              pw.SizedBox(width: 12),
              _cardResumo(
                'Quantidade de vendas',
                vendasFinalizadas.length.toString(),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Formas de pagamento',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          _tabelaPagamentos(totaisPorPagamento),
          pw.SizedBox(height: 16),
          pw.Text(
            'Produtos vendidos',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          _tabelaProdutos(resumoProdutos),
          if (detalhado) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              'Vendas e itens',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            _tabelaVendas(vendas),
          ],
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _cardResumo(String titulo, String valor) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(titulo),
            pw.SizedBox(height: 6),
            pw.Text(
              valor,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _tabelaPagamentos(Map<String, double> totais) {
    if (totais.isEmpty) return pw.Text('Nenhum pagamento no periodo');

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      children: [
        _linha(['Forma', 'Valor'], header: true),
        ...totais.entries.map(
          (e) => _linha([e.key.toUpperCase(), _moeda(e.value)]),
        ),
      ],
    );
  }

  static pw.Widget _tabelaProdutos(Map<String, Map<String, double>> resumo) {
    if (resumo.isEmpty) return pw.Text('Nenhum produto vendido no periodo');

    final itens = resumo.entries.toList()
      ..sort(
        (a, b) => b.value['quantidade']!.compareTo(a.value['quantidade']!),
      );

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      children: [
        _linha(['Produto', 'Qtd', 'Total'], header: true),
        ...itens.map(
          (e) => _linha([
            e.key,
            (e.value['quantidade'] ?? 0).toStringAsFixed(0),
            _moeda(e.value['total'] ?? 0),
          ]),
        ),
      ],
    );
  }

  static pw.Widget _tabelaVendas(List<Map<String, dynamic>> vendas) {
    if (vendas.isEmpty) return pw.Text('Nenhuma venda no periodo');

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(55),
        1: pw.FixedColumnWidth(55),
        2: pw.FlexColumnWidth(),
        3: pw.FlexColumnWidth(),
        4: pw.FixedColumnWidth(80),
      },
      children: [
        _linha(['Venda', 'Hora', 'Cliente', 'Itens', 'Total'], header: true),
        ...vendas.map((venda) {
          final data = DateTime.tryParse(venda['data_venda'].toString());
          final cliente = venda['clientes'] as Map<String, dynamic>?;
          final total = ((venda['total'] as num?)?.toDouble() ?? 0);
          final cancelada =
              (venda['status'] ?? 'finalizada').toString() == 'cancelada';
          final itens = List<Map<String, dynamic>>.from(
            venda['venda_itens'] ?? [],
          );
          final itensTexto = itens.map((item) {
            final produto = item['produtos'] as Map<String, dynamic>? ?? {};
            final qtd = ((item['quantidade'] as num?)?.toDouble() ?? 0);
            return '${qtd.toStringAsFixed(0)}x ${produto['descricao'] ?? 'Produto'}';
          }).join('\n');

          return _linha([
            (venda['numero'] ?? venda['id'] ?? '').toString(),
            data == null
                ? ''
                : '${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}',
            cliente?['nome']?.toString() ?? 'Sem cliente',
            cancelada ? 'CANCELADA\n$itensTexto' : itensTexto,
            cancelada ? 'CANCELADA' : _moeda(total),
          ]);
        }),
      ],
    );
  }

  static pw.TableRow _linha(List<String> colunas, {bool header = false}) {
    return pw.TableRow(
      decoration: header
          ? const pw.BoxDecoration(color: PdfColors.grey200)
          : null,
      children: colunas.map((texto) {
        return pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(
            texto,
            style: header
                ? pw.TextStyle(fontWeight: pw.FontWeight.bold)
                : null,
          ),
        );
      }).toList(),
    );
  }

  static String _data(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  static String _moeda(double valor) {
    return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  }
}
