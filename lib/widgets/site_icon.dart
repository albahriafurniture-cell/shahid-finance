import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/favicon_service.dart';
import '../theme.dart';
import '../utils/site_catalog.dart';

/// v1.1.8: a site's ORIGINAL favicon when it can be fetched,
/// the coloured monogram tile otherwise.
///
/// While loading, on any fetch failure, and whenever the fetched
/// bytes cannot be decoded (e.g. a raw ICO file), the tile shows
/// the site's monogram on its brand-colour-family background —
/// never a broken image, never blank.
class SiteIcon extends StatefulWidget {
  final SiteInfo site;
  final double size;
  const SiteIcon({super.key, required this.site, this.size = 44});

  @override
  State<SiteIcon> createState() => _SiteIconState();
}

class _SiteIconState extends State<SiteIcon> {
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bytes = await FaviconService.load(widget.site);
    if (!mounted) return;
    setState(() {
      if (bytes == null) {
        _failed = true;
      } else {
        _bytes = bytes;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final monogram = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: widget.site.color,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      alignment: Alignment.center,
      child: Text(
        widget.site.monogram,
        style: TextStyle(
          color: widget.site.onTile,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    if (_bytes == null || _failed) return monogram;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Image.memory(
        _bytes!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => monogram,
      ),
    );
  }
}
