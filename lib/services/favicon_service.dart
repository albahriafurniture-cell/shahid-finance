import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../utils/site_catalog.dart';

/// v1.1.8: ORIGINAL site icons, the legitimate password-manager way.
///
/// Nothing is bundled into the repo and no logo artwork is copied
/// by hand: at runtime on the phone, each site's own publicly
/// published favicon is fetched and cached locally (app documents,
/// never in cloud backup). The coloured monogram tile stays ONLY as
/// the offline/failure fallback.
///
/// Source order (per site):
/// 1. The standard favicon lookup service (Google s2) for the
///    site's domain - it returns the site's own favicon as a PNG,
///    which Flutter can decode. This is primary because a site's
///    raw favicon.ico is usually ICO format, which Flutter cannot
///    render.
/// 2. The site's own favicon.ico URL, tried only if
///    the lookup service fails. If it is ICO (or anything else
///    Flutter cannot decode), the tile's errorBuilder falls back
///    to the monogram — never a broken image.
/// No other app is downloaded or decompiled to obtain icons.
typedef FaviconFetcher = Future<Uint8List?> Function(Uri url);

/// Cache key for a site: its canonical domain (lowercase, no
/// scheme/www/path). Raw text is normalized the same way, so
/// "https://www.Facebook.com/profile" and "facebook.com" share
/// one cache entry.
String faviconCacheKey(String input) => normalizeSiteText(input);

String faviconCacheKeyForSite(SiteInfo site) =>
    faviconCacheKey(site.canonical);

/// Candidate favicon URLs for a site, in try order.
List<Uri> faviconCandidates(SiteInfo site) {
  final domain = faviconCacheKeyForSite(site);
  if (domain.isEmpty) return [];
  return [
    Uri.parse(
        'https://www.google.com/s2/favicons?domain=$domain&sz=128'),
    Uri.parse('https://$domain/favicon.ico'),
  ];
}

File faviconCacheFile(Directory dir, String key) =>
    File('${dir.path}/favicons/$key.bin');

class FaviconService {
  static Directory? _dirOverride;
  static final Map<String, Uint8List> _memory = {};

  /// Test seam: point the file cache at a temp directory.
  static void useDirectoryForTest(Directory dir) {
    _dirOverride = dir;
    _memory.clear();
  }

  static void clearMemoryForTest() => _memory.clear();

  static Future<Directory> _dir() async {
    if (_dirOverride != null) return _dirOverride!;
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/favicons');
  }

  static Future<Uint8List?> _defaultFetch(Uri url) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(url);
      final res = await req.close().timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final bytes = await res.fold<BytesBuilder>(
          BytesBuilder(), (b, d) => b..add(d)).then((b) => b.takeBytes());
      if (bytes.isEmpty || bytes.length > 512 * 1024) return null;
      return bytes;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// Load a site's favicon bytes: memory cache, then file cache,
  /// then network (candidates in order). Returns null on ANY
  /// failure — callers show the monogram tile instead.
  static Future<Uint8List?> load(
    SiteInfo site, {
    FaviconFetcher? fetcher,
  }) async {
    final key = faviconCacheKeyForSite(site);
    if (key.isEmpty) return null;
    if (_memory.containsKey(key)) return _memory[key];
    final dir = await _dir();
    final file = faviconCacheFile(dir, key);
    if (await file.exists()) {
      try {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          _memory[key] = bytes;
          return bytes;
        }
      } catch (_) {
        // Corrupt cache entry: fall through to a fresh fetch.
      }
    }
    final fetch = fetcher ?? _defaultFetch;
    for (final url in faviconCandidates(site)) {
      final bytes = await fetch(url);
      if (bytes != null && bytes.isNotEmpty) {
        _memory[key] = bytes;
        try {
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes);
        } catch (_) {
          // Cache write failure must never break the tile.
        }
        return bytes;
      }
    }
    return null;
  }
}
