import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

/// Maps a locale/script to a Noto Sans font download URL (GitHub raw, OFL licensed).
///
/// All fonts are from https://github.com/google/fonts under the
/// SIL Open Font License — free to fetch, embed, and redistribute.
const Map<String, String> _scriptFontUrls = {
  // Latin, Cyrillic, Greek, IPA — base font, always loaded
  'NotoSans': 'https://github.com/google/fonts/raw/main/ofl/notosans/NotoSans%5Bwdth%2Cwght%5D.ttf',

  // South Asia
  'NotoSansBengali':    'https://github.com/google/fonts/raw/main/ofl/notosansbengali/NotoSansBengali%5Bwdth%2Cwght%5D.ttf',
  'NotoSansDevanagari': 'https://github.com/google/fonts/raw/main/ofl/notosansdevanagari/NotoSansDevanagari%5Bwdth%2Cwght%5D.ttf',
  'NotoSansGujarati':   'https://github.com/google/fonts/raw/main/ofl/notosansgujarati/NotoSansGujarati%5Bwdth%2Cwght%5D.ttf',
  'NotoSansGurmukhi':   'https://github.com/google/fonts/raw/main/ofl/notosansgurmukhi/NotoSansGurmukhi%5Bwdth%2Cwght%5D.ttf',
  'NotoSansTamil':      'https://github.com/google/fonts/raw/main/ofl/notosanstamil/NotoSansTamil%5Bwdth%2Cwght%5D.ttf',
  'NotoSansTelugu':     'https://github.com/google/fonts/raw/main/ofl/notosanstelugu/NotoSansTelugu%5Bwdth%2Cwght%5D.ttf',
  'NotoSansKannada':    'https://github.com/google/fonts/raw/main/ofl/notosanskannada/NotoSansKannada%5Bwdth%2Cwght%5D.ttf',
  'NotoSansMalayalam':  'https://github.com/google/fonts/raw/main/ofl/notosansmalayalam/NotoSansMalayalam%5Bwdth%2Cwght%5D.ttf',
  'NotoSansSinhala':    'https://github.com/google/fonts/raw/main/ofl/notosanssinhala/NotoSansSinhala%5Bwdth%2Cwght%5D.ttf',

  // Middle East & Central Asia
  'NotoSansArabic':  'https://github.com/google/fonts/raw/main/ofl/notosansarabic/NotoSansArabic%5Bwdth%2Cwght%5D.ttf',
  'NotoSansHebrew':  'https://github.com/google/fonts/raw/main/ofl/notosanshebrew/NotoSansHebrew%5Bwdth%2Cwght%5D.ttf',

  // Southeast Asia
  'NotoSansThai':       'https://github.com/google/fonts/raw/main/ofl/notosansthai/NotoSansThai%5Bwdth%2Cwght%5D.ttf',
  'NotoSansKhmer':      'https://github.com/google/fonts/raw/main/ofl/notosanskhmer/NotoSansKhmer%5Bwdth%2Cwght%5D.ttf',
  'NotoSansMyanmar':    'https://github.com/google/fonts/raw/main/ofl/notosansmyanmar/NotoSansMyanmar%5Bwdth%2Cwght%5D.ttf',

  // East Asia (large files ~5–10 MB each — fetched only on demand)
  'NotoSansSC': 'https://github.com/google/fonts/raw/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf',  // Simplified Chinese
  'NotoSansTC': 'https://github.com/google/fonts/raw/main/ofl/notosanstc/NotoSansTC%5Bwght%5D.ttf',  // Traditional Chinese
  'NotoSansJP': 'https://github.com/google/fonts/raw/main/ofl/notosansjp/NotoSansJP%5Bwght%5D.ttf',  // Japanese
  'NotoSansKR': 'https://github.com/google/fonts/raw/main/ofl/notosanskr/NotoSansKR%5Bwght%5D.ttf',  // Korean
};

/// Maps a locale language code to the list of Noto font names needed.
/// NotoSans (Latin) is always included as the base.
const Map<String, List<String>> _localeToFonts = {
  // South Asia
  'bn': ['NotoSansBengali'],                        // Bengali
  'hi': ['NotoSansDevanagari'],                     // Hindi
  'mr': ['NotoSansDevanagari'],                     // Marathi
  'ne': ['NotoSansDevanagari'],                     // Nepali
  'gu': ['NotoSansGujarati'],                       // Gujarati
  'pa': ['NotoSansGurmukhi'],                       // Punjabi
  'ta': ['NotoSansTamil'],                          // Tamil
  'te': ['NotoSansTelugu'],                         // Telugu
  'kn': ['NotoSansKannada'],                        // Kannada
  'ml': ['NotoSansMalayalam'],                      // Malayalam
  'si': ['NotoSansSinhala'],                        // Sinhala

  // Middle East
  'ar': ['NotoSansArabic'],                         // Arabic
  'ur': ['NotoSansArabic'],                         // Urdu
  'fa': ['NotoSansArabic'],                         // Persian/Farsi
  'he': ['NotoSansHebrew'],                         // Hebrew

  // Southeast Asia
  'th': ['NotoSansThai'],                           // Thai
  'km': ['NotoSansKhmer'],                          // Khmer
  'my': ['NotoSansMyanmar'],                        // Myanmar/Burmese

  // East Asia
  'zh': ['NotoSansSC'],                             // Chinese (Simplified default)
  'zh_TW': ['NotoSansTC'],                          // Chinese (Traditional)
  'zh_HK': ['NotoSansTC'],                          // Chinese (Hong Kong)
  'ja': ['NotoSansJP'],                             // Japanese
  'ko': ['NotoSansKR'],                             // Korean
};

/// Service that downloads, caches, and loads Noto fonts for PDF generation.
class PdfFontService {
  /// Loads fonts appropriate for the given [languageCode] (e.g. 'bn', 'ar').
  /// Always includes NotoSans (Latin) as the base font.
  /// Returns a list of [pw.Font] ready to use as [fontFallback] in TextStyle.
  ///
  /// Fonts are cached in the app's support directory after the first download,
  /// so subsequent calls are instant (no network needed).
  static Future<List<pw.Font>> loadFontsForLocale(String languageCode) async {
    // Normalise: 'bn_BD' → try 'bn_BD' first, fallback to 'bn'
    final fontNames = _localeToFonts[languageCode] ??
        _localeToFonts[languageCode.split('_').first] ??
        [];

    // Always load the base Latin font
    final fontsToLoad = {'NotoSans', ...fontNames};

    final List<pw.Font> fonts = [];
    for (final name in fontsToLoad) {
      final font = await _loadFont(name);
      if (font != null) fonts.add(font);
    }
    return fonts;
  }

  /// Loads a single font by name, using the device cache if available.
  static Future<pw.Font?> _loadFont(String name) async {
    try {
      // 1. Try bundled asset first (fast path for pre-bundled fonts)
      try {
        final data = await rootBundle.load('assets/fonts/$name.ttf');
        return pw.Font.ttf(data);
      } catch (_) {
        // Not bundled — fall through to cache / network
      }

      // 2. Check device cache
      final cacheFile = await _cacheFile(name);
      if (await cacheFile.exists()) {
        final bytes = await cacheFile.readAsBytes();
        return pw.Font.ttf(ByteData.sublistView(bytes));
      }

      // 3. Download from GitHub (Noto fonts, OFL licence — free to fetch)
      final url = _scriptFontUrls[name];
      if (url == null) return null;

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) return null;

      final bytes = await response
          .fold<List<int>>([], (buf, chunk) => buf..addAll(chunk));
      client.close();

      // 4. Write to cache so the next call is instant
      await cacheFile.writeAsBytes(bytes);
      return pw.Font.ttf(ByteData.sublistView(Uint8List.fromList(bytes)));
    } catch (e) {
      // If anything fails (offline, 404, etc.) skip this font silently.
      return null;
    }
  }

  /// Returns the local cache [File] path for a given font name.
  static Future<File> _cacheFile(String name) async {
    final dir = await getApplicationSupportDirectory();
    final fontsDir = Directory('${dir.path}/pdf_fonts');
    await fontsDir.create(recursive: true);
    return File('${fontsDir.path}/$name.ttf');
  }

  /// Clears cached fonts (useful if you want to force a re-download).
  static Future<void> clearCache() async {
    final dir = await getApplicationSupportDirectory();
    final fontsDir = Directory('${dir.path}/pdf_fonts');
    if (await fontsDir.exists()) await fontsDir.delete(recursive: true);
  }
}
