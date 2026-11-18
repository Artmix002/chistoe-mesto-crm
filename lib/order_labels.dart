import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'models.dart';

final _labelBarcode = Barcode.code128();
final _thermalLabelFormat = PdfPageFormat(
  58 * PdfPageFormat.mm,
  40 * PdfPageFormat.mm,
  marginAll: 0,
);

/// Opens an in-app preview and sends the same data to the system print dialog
/// using the exact 58 x 40 mm page size required by the thermal printer.
Future<void> showOrderLabels(
  BuildContext context,
  List<Order> orders, {
  required String title,
}) async {
  if (orders.isEmpty) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) =>
        _OrderLabelsDialog(orders: orders, title: title),
  );
}

class _OrderLabelsDialog extends StatefulWidget {
  const _OrderLabelsDialog({required this.orders, required this.title});

  final List<Order> orders;
  final String title;

  @override
  State<_OrderLabelsDialog> createState() => _OrderLabelsDialogState();
}

class _OrderLabelsDialogState extends State<_OrderLabelsDialog> {
  final _page = PageController();
  var _index = 0;
  var _openingPrint = false;

  Future<void> _print() async {
    setState(() => _openingPrint = true);
    try {
      await Printing.layoutPdf(
        name: 'Этикетки заказов',
        format: _thermalLabelFormat,
        dynamicLayout: false,
        forceCustomPrintPaper: true,
        onLayout: (_) => buildOrderLabelsPdf(widget.orders),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось открыть системное окно печати'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _openingPrint = false);
    }
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 580,
      height: 460,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _page,
              itemCount: widget.orders.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (_, index) => Center(
                child: AspectRatio(
                  aspectRatio: 58 / 40,
                  child: _LabelPreview(order: widget.orders[index]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('${_index + 1} из ${widget.orders.length}'),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Закрыть'),
      ),
      FilledButton.icon(
        onPressed: _openingPrint ? null : _print,
        icon: _openingPrint
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.print_outlined),
        label: Text(
          widget.orders.length == 1 ? 'Распечатать' : 'Распечатать все',
        ),
      ),
    ],
  );
}

class _LabelPreview extends StatelessWidget {
  const _LabelPreview({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final code = labelBarcodeData(order);
    final isReturn = isOrderReturn(order);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF111827), width: 1.5),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.black, fontSize: 13, height: 1.1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                isReturn
                    ? 'ВОЗВРАТ · ${orderDeliveryService(order).toUpperCase()}'
                    : orderDeliveryService(order).toUpperCase(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Divider(height: 8, color: Colors.black),
            if (isReturn && order.pvz.isNotEmpty) ...[
              Text(
                order.pvz,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              order.product.isEmpty ? 'Товар не указан' : order.product,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            Text(
              'АРТ. ${order.article.isEmpty ? 'НЕ СВЯЗАН' : order.article}   ·   ${_quantity(order.quantity)} ШТ.',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            _BarcodePreview(code: code),
          ],
        ),
      ),
    );
  }
}

class _BarcodePreview extends StatelessWidget {
  const _BarcodePreview({required this.code});
  final String code;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 58,
        width: double.infinity,
        child: BarcodeWidget(
          barcode: _labelBarcode,
          data: code,
          drawText: false,
          color: Colors.black,
          backgroundColor: Colors.white,
          errorBuilder: (_, _) => const SizedBox.shrink(),
        ),
      ),
      Center(
        child: Text(
          code,
          style: const TextStyle(fontSize: 10, letterSpacing: 1.2),
        ),
      ),
    ],
  );
}

String _quantity(double value) =>
    value % 1 == 0 ? value.toInt().toString() : value.toString();

/// Returns use a different label: the pickup point is useful only when the
/// parcel is coming back to the seller.
bool isOrderReturn(Order order) {
  final text = '${order.status} ${order.comment} ${order.avitoStatus}'
      .toLowerCase();
  return order.status == 'returned' || text.contains('возврат');
}

/// Carrier name taken from the order data collected from Avito. Older orders
/// have the service in [Order.comment], so this remains compatible with the
/// existing saved data as well as newly imported orders.
String orderDeliveryService(Order order) {
  const services = [
    'Почта России',
    'Яндекс',
    'Яндекс Доставка',
    'СДЭК',
    'Boxberry',
    '5Post',
    'DPD',
    'DHL',
  ];
  final source = '${order.comment} ${order.avitoStatus}'.toLowerCase();
  for (final service in services) {
    if (source.contains(service.toLowerCase())) return service;
  }
  return order.source == 'avito' ? 'Авито' : 'Доставка';
}

/// Data encoded into a standard Code 128 barcode on every thermal label.
/// The exact tracking number takes precedence; manual orders fall back to the
/// CRM order number, so every label remains machine-readable.
String labelBarcodeData(Order order) {
  final value = order.barcode.isNotEmpty
      ? order.barcode
      : order.number.toString();
  final ascii = value
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
      .trim();
  return ascii.isEmpty ? 'ORDER-${order.number}' : ascii;
}

Future<Uint8List> buildOrderLabelsPdf(List<Order> orders) async {
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/PTSans-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/PTSans-Bold.ttf'),
  );
  final document = pw.Document();
  final theme = pw.ThemeData.withFont(base: regular, bold: bold);

  for (final order in orders) {
    document.addPage(
      pw.Page(
        pageFormat: _thermalLabelFormat,
        theme: theme,
        build: (_) => _pdfLabel(order, regular: regular, bold: bold),
      ),
    );
  }
  return document.save();
}

pw.Widget _pdfLabel(
  Order order, {
  required pw.Font regular,
  required pw.Font bold,
}) {
  final code = labelBarcodeData(order);
  final isReturn = isOrderReturn(order);
  return pw.Padding(
    padding: pw.EdgeInsets.all(2.2 * PdfPageFormat.mm),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(
          child: pw.Text(
            isReturn
                ? 'ВОЗВРАТ · ${orderDeliveryService(order).toUpperCase()}'
                : orderDeliveryService(order).toUpperCase(),
            style: pw.TextStyle(
              fontSize: 8,
              font: bold,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Divider(thickness: .7),
        if (isReturn && order.pvz.isNotEmpty) ...[
          pw.Text(
            order.pvz,
            maxLines: 2,
            overflow: pw.TextOverflow.clip,
            style: pw.TextStyle(
              fontSize: 7.5,
              font: bold,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
        ],
        pw.Text(
          order.product.isEmpty ? 'Товар не указан' : order.product,
          maxLines: 2,
          overflow: pw.TextOverflow.clip,
          style: pw.TextStyle(
            fontSize: 7.5,
            font: bold,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'АРТ. ${order.article.isEmpty ? 'НЕ СВЯЗАН' : order.article} · ${_quantity(order.quantity)} ШТ.',
          style: pw.TextStyle(fontSize: 6.5, font: bold),
        ),
        pw.Spacer(),
        pw.Center(
          child: pw.SizedBox(
            width: double.infinity,
            height: 32,
            child: pw.SvgImage(svg: _barcodeSvg(code), fit: pw.BoxFit.fill),
          ),
        ),
        pw.Center(
          child: pw.Text(code, style: pw.TextStyle(fontSize: 6, font: regular)),
        ),
      ],
    ),
  );
}

String _barcodeSvg(String code) {
  return _labelBarcode.toSvg(code, width: 530, height: 85, drawText: false);
}
