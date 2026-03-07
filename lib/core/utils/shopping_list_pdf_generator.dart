import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../data/models/meal.dart';

/// Generates a shopping-list PDF by rendering Flutter widgets off-screen.
///
/// Flutter's rendering engine (HarfBuzz via Skia/Impeller) handles complex
/// scripts — Bengali, Arabic, Devanagari — correctly. The rendered widget is
/// captured as a PNG via [RenderRepaintBoundary.toImage] and embedded in the PDF.
class ShoppingListPdfGenerator {
  static Future<File?> generateShoppingListPdf(
    List<Meal> meals,
    BuildContext context,
  ) async {
    // ── Aggregate groceries ──────────────────────────────────────────────────
    final Map<String, int?> groceries = {};
    for (final meal in meals) {
      if (meal.groceries != null && meal.groceries!.isNotEmpty) {
        for (final g in meal.groceries!) {
          final amount = double.tryParse(g.amountInGm.trim())?.round() ?? 0;
          groceries[g.name] = (groceries[g.name] ?? 0) + amount;
        }
      } else if (meal.groceryNames != null) {
        for (final name in meal.groceryNames!) {
          groceries.putIfAbsent(name, () => null);
        }
      }
    }

    // ── Render widget to PNG via Flutter's engine ────────────────────────────
    //   The widget is inserted into an off-screen Overlay, painted for one
    //   frame, then captured with RenderRepaintBoundary.toImage().
    //   Bengali text is shaped by HarfBuzz and rendered by Skia — correct
    //   ligatures and matra positions with no extra font setup needed.
    final pngBytes = await _captureWidget(
      context,
      _ShoppingListWidget(groceries: groceries),
      width: 595.0,   // A4 logical width (points)
      pixelRatio: 3.0, // 3× → ~210 dpi on A4 — sharp enough for printing
    );

    // ── Build the PDF ────────────────────────────────────────────────────────
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Image(pw.MemoryImage(pngBytes), fit: pw.BoxFit.contain),
    ));

    return _save(await pdf.save());
  }

  // ── Off-screen rendering ───────────────────────────────────────────────────

  static Future<Uint8List> _captureWidget(
    BuildContext context,
    Widget widget, {
    required double width,
    double pixelRatio = 3.0,
  }) async {
    final repaintKey = GlobalKey();
    final completer = Completer<Uint8List>();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        // Place far off-screen so it is invisible to the user.
        left: -100000,
        top: -100000,
        width: width,
        child: Material(
          color: Colors.white,
          child: RepaintBoundary(
            key: repaintKey,
            child: widget,
          ),
        ),
      ),
    );

    Overlay.of(context).insert(entry);

    // Wait two frames: one to lay out, one to paint.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final boundary = repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
          if (boundary == null) {
            completer.completeError('RepaintBoundary not found');
            return;
          }
          final image = await boundary.toImage(pixelRatio: pixelRatio);
          final data =
              await image.toByteData(format: ui.ImageByteFormat.png);
          completer.complete(data!.buffer.asUint8List());
        } catch (e) {
          completer.completeError(e);
        } finally {
          entry.remove();
        }
      });
    });

    return completer.future;
  }

  // ── Save / Share ───────────────────────────────────────────────────────────

  static Future<File?> _save(Uint8List bytes) async {
    final name = 'shopping_list_${DateTime.now().millisecondsSinceEpoch}.pdf';
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)],
          text: 'Shopping list from Kikhabo', subject: 'Shopping List');
      return file;
    }
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Shopping List PDF',
      fileName: name,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (path == null) return null;
    final file = File(path);
    await file.writeAsBytes(bytes);
    return file;
  }
}

// ── Shopping list Flutter widget ─────────────────────────────────────────────
// Text() here uses Flutter's full text pipeline. GoogleFonts.notoSansBengali()
// is downloaded & cached by the google_fonts package (already in pubspec.yaml),
// guaranteeing Bengali glyphs and correct HarfBuzz shaping on all devices.

class _ShoppingListWidget extends StatelessWidget {
  final Map<String, int?> groceries;
  const _ShoppingListWidget({required this.groceries});

  static const _primary = Color(0xFF047857);
  static const _accent = Color(0xFFF97316);
  static const _green = Color(0xFF10B981);

  TextStyle _t(double size, {FontWeight w = FontWeight.normal, Color? c}) =>
      GoogleFonts.notoSansBengali(
          fontSize: size, fontWeight: w, color: c ?? Colors.black87);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.restaurant_menu,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Kikhabo', style: _t(22, w: FontWeight.bold, c: _primary)),
                Text('Your Meal Planning Assistant',
                    style: _t(11, c: Colors.grey)),
              ]),
            ]),
            const SizedBox(height: 20),

            // ── Title ────────────────────────────────────────────────────────
            Center(child: Text('Shopping List', style: _t(20, w: FontWeight.bold, c: _primary))),
            const SizedBox(height: 4),
            Center(child: Text('Kikhabo Meal Plan', style: _t(12, c: _green))),
            const SizedBox(height: 16),
            Container(height: 2, color: _primary),
            const SizedBox(height: 12),

            // ── Column headers ────────────────────────────────────────────────
            Row(children: [
              Expanded(child: Text('Item', style: _t(11, w: FontWeight.w600, c: Colors.grey))),
              Text('Amount', style: _t(11, w: FontWeight.w600, c: Colors.grey)),
            ]),
            const SizedBox(height: 6),
            Container(height: 1, color: Colors.grey.shade300),
            const SizedBox(height: 8),

            // ── Grocery rows ──────────────────────────────────────────────────
            // Bengali text (e.g. "আলু", "টমেটো") renders correctly here
            // because Flutter's engine does full Unicode shaping.
            ...groceries.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Expanded(child: Text('• ${e.key}', style: _t(13))),
                    if (e.value != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                            color: _accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text('${e.value}g',
                            style: _t(13, w: FontWeight.bold, c: _accent)),
                      )
                    else
                      Text('N/A', style: _t(12, c: Colors.grey)),
                  ]),
                )),

            const SizedBox(height: 24),
            Container(height: 1, color: _primary),
            const SizedBox(height: 10),
            Center(
              child: Text('Generated by Kikhabo AI',
                  style: GoogleFonts.notoSansBengali(
                      fontSize: 10,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic)),
            ),
          ],
        ),
      ),
    );
  }
}
