import 'package:flutter/material.dart';

import '../services/vault_service.dart';

/// v1.1.8: built-in catalog of the major social media apps/sites
/// plus the biggest general sites, for the Password Manager.
///
/// IMPORTANT — no company logo artwork is copied here. Every tile is
/// an ORIGINAL design: a plain coloured circle/rounded tile carrying
/// only a 1–2 letter monogram, in the site's brand colour family.
/// Unknown sites fall back to a neutral tile with the site's first
/// letter, so nothing ever renders without an icon.
class SiteInfo {
  final String key; // stable catalog key, e.g. 'facebook'
  final String name; // display name, e.g. 'Facebook'
  final String monogram; // 1–2 letters shown on the tile
  final Color color; // tile background (brand colour family)
  final Color onTile; // monogram colour
  final String canonical; // canonical domain stored on pick
  final List<String> matchKeys; // lowercase match variants
  final bool social; // true for social media apps/sites

  const SiteInfo({
    required this.key,
    required this.name,
    required this.monogram,
    required this.color,
    this.onTile = Colors.white,
    required this.canonical,
    required this.matchKeys,
    this.social = false,
  });
}

const _neutralTile = Color(0xFF5A6472);

const siteCatalog = <SiteInfo>[
  SiteInfo(
    key: 'facebook',
    name: 'Facebook',
    monogram: 'f',
    color: Color(0xFF1877F2),
    canonical: 'facebook.com',
    matchKeys: ['facebook', 'fb', 'meta'],
    social: true,
  ),
  SiteInfo(
    key: 'instagram',
    name: 'Instagram',
    monogram: 'IG',
    color: Color(0xFFE1306C),
    canonical: 'instagram.com',
    matchKeys: ['instagram', 'insta', 'ig'],
    social: true,
  ),
  SiteInfo(
    key: 'whatsapp',
    name: 'WhatsApp',
    monogram: 'WA',
    color: Color(0xFF25D366),
    canonical: 'whatsapp.com',
    matchKeys: ['whatsapp', 'wa'],
    social: true,
  ),
  SiteInfo(
    key: 'x',
    name: 'X (Twitter)',
    monogram: 'X',
    color: Color(0xFF1D9BF0),
    canonical: 'x.com',
    matchKeys: ['x', 'twitter', 'tweet'],
    social: true,
  ),
  SiteInfo(
    key: 'youtube',
    name: 'YouTube',
    monogram: 'YT',
    color: Color(0xFFFF0000),
    canonical: 'youtube.com',
    matchKeys: ['youtube', 'yt'],
    social: true,
  ),
  SiteInfo(
    key: 'tiktok',
    name: 'TikTok',
    monogram: 'TT',
    color: Color(0xFFFE2C55),
    canonical: 'tiktok.com',
    matchKeys: ['tiktok', 'tik tok'],
    social: true,
  ),
  SiteInfo(
    key: 'snapchat',
    name: 'Snapchat',
    monogram: 'SC',
    color: Color(0xFFFFFC00),
    onTile: Color(0xFF1A1A1A),
    canonical: 'snapchat.com',
    matchKeys: ['snapchat', 'snap'],
    social: true,
  ),
  SiteInfo(
    key: 'telegram',
    name: 'Telegram',
    monogram: 'TG',
    color: Color(0xFF229ED9),
    canonical: 'telegram.org',
    matchKeys: ['telegram'],
    social: true,
  ),
  SiteInfo(
    key: 'linkedin',
    name: 'LinkedIn',
    monogram: 'in',
    color: Color(0xFF0A66C2),
    canonical: 'linkedin.com',
    matchKeys: ['linkedin'],
    social: true,
  ),
  SiteInfo(
    key: 'pinterest',
    name: 'Pinterest',
    monogram: 'P',
    color: Color(0xFFE60023),
    canonical: 'pinterest.com',
    matchKeys: ['pinterest', 'pin'],
    social: true,
  ),
  SiteInfo(
    key: 'reddit',
    name: 'Reddit',
    monogram: 'R',
    color: Color(0xFFFF4500),
    canonical: 'reddit.com',
    matchKeys: ['reddit'],
    social: true,
  ),
  SiteInfo(
    key: 'threads',
    name: 'Threads',
    monogram: 'Th',
    color: Color(0xFF333333),
    canonical: 'threads.net',
    matchKeys: ['threads'],
    social: true,
  ),
  SiteInfo(
    key: 'messenger',
    name: 'Messenger',
    monogram: 'M',
    color: Color(0xFF0084FF),
    canonical: 'messenger.com',
    matchKeys: ['messenger', 'fb messenger'],
    social: true,
  ),
  SiteInfo(
    key: 'google',
    name: 'Gmail / Google',
    monogram: 'G',
    color: Color(0xFF4285F4),
    canonical: 'gmail.com',
    matchKeys: ['gmail', 'google', 'googlemail'],
  ),
  SiteInfo(
    key: 'yahoo',
    name: 'Yahoo',
    monogram: 'Y',
    color: Color(0xFF6001D2),
    canonical: 'yahoo.com',
    matchKeys: ['yahoo', 'ymail'],
  ),
  SiteInfo(
    key: 'outlook',
    name: 'Outlook / Hotmail',
    monogram: 'O',
    color: Color(0xFF0072C6),
    canonical: 'outlook.com',
    matchKeys: ['outlook', 'hotmail', 'live', 'msn'],
  ),
  SiteInfo(
    key: 'amazon',
    name: 'Amazon',
    monogram: 'a',
    color: Color(0xFFFF9900),
    canonical: 'amazon.com',
    matchKeys: ['amazon'],
  ),
  SiteInfo(
    key: 'netflix',
    name: 'Netflix',
    monogram: 'N',
    color: Color(0xFFE50914),
    canonical: 'netflix.com',
    matchKeys: ['netflix'],
  ),
  SiteInfo(
    key: 'spotify',
    name: 'Spotify',
    monogram: 'Sp',
    color: Color(0xFF1DB954),
    canonical: 'spotify.com',
    matchKeys: ['spotify'],
  ),
  SiteInfo(
    key: 'github',
    name: 'GitHub',
    monogram: 'GH',
    color: Color(0xFF6E7681),
    canonical: 'github.com',
    matchKeys: ['github', 'git hub'],
  ),
  SiteInfo(
    key: 'easypaisa',
    name: 'Easypaisa',
    monogram: 'EP',
    color: Color(0xFF009E60),
    canonical: 'easypaisa.com.pk',
    matchKeys: ['easypaisa', 'easy paisa'],
  ),
  SiteInfo(
    key: 'jazzcash',
    name: 'JazzCash',
    monogram: 'JC',
    color: Color(0xFFE40000),
    canonical: 'jazzcash.com.pk',
    matchKeys: ['jazzcash', 'jazz cash'],
  ),
  SiteInfo(
    key: 'meezan',
    name: 'Meezan Bank',
    monogram: 'MB',
    color: Color(0xFF5B2C83),
    canonical: 'meezanbank.com',
    matchKeys: ['meezan', 'meezanbank'],
  ),
];

/// Normalize free text for matching: lowercase, strip scheme,
/// leading www., and any path/query.
String normalizeSiteText(String input) {
  var s = input.trim().toLowerCase();
  s = s.replaceFirst(RegExp(r'^https?://'), '');
  s = s.replaceFirst(RegExp(r'^www\.'), '');
  final cut = s.indexOf(RegExp(r'[/?#]'));
  if (cut >= 0) s = s.substring(0, cut);
  return s.trim();
}

/// Resolve ANY text — a catalog pick, a domain, an app name, or a
/// legacy v1.1.7 free-text website — to its site tile.
///
/// Matching is case-insensitive and domain-tolerant: exact match
/// keys win, then whole-token matches (so "fb" matches Facebook but
/// never a substring inside another word), then a contains-match
/// for longer keys (so "meezanbank.com" still finds Meezan).
/// Returns null for unknown/empty input; callers use [fallbackSite].
SiteInfo? resolveSite(String input) {
  final norm = normalizeSiteText(input);
  if (norm.isEmpty) return null;
  for (final site in siteCatalog) {
    if (site.matchKeys.contains(norm)) return site;
  }
  final tokens = norm.split(RegExp(r'[^a-z0-9]+')).where((t) => t.isNotEmpty);
  for (final site in siteCatalog) {
    for (final key in site.matchKeys) {
      if (tokens.contains(key)) return site;
    }
  }
  for (final site in siteCatalog) {
    for (final key in site.matchKeys) {
      if (key.length >= 4 && norm.contains(key)) return site;
    }
  }
  return null;
}

/// Neutral fallback tile for unknown sites: first letter of the
/// site text (or '?' when there is none). Key is namespaced so two
/// different custom sites never merge into one group.
SiteInfo fallbackSite(String input) {
  final norm = normalizeSiteText(input);
  final letter = norm.isEmpty
      ? '?'
      : norm[0].toUpperCase();
  return SiteInfo(
    key: 'custom:$norm',
    name: input.trim().isEmpty ? 'Other' : input.trim(),
    monogram: letter,
    color: _neutralTile,
    canonical: norm,
    matchKeys: const [],
  );
}

/// Resolve an entry to its tile, falling back to neutral.
SiteInfo siteForEntry(VaultEntry e) =>
    resolveSite(e.website.isNotEmpty ? e.website : e.title) ??
    fallbackSite(e.website.isNotEmpty ? e.website : e.title);

/// One site + all of its accounts, for the grouped vault view.
class SiteGroup {
  final SiteInfo site;
  final List<VaultEntry> entries;
  const SiteGroup(this.site, this.entries);
}

/// Group entries by resolved site. Multiple accounts for the same
/// site always land in one group and are never merged or dropped.
/// Groups sort by account count (most first), then name.
List<SiteGroup> groupEntries(List<VaultEntry> entries) {
  final byKey = <String, List<VaultEntry>>{};
  final siteByKey = <String, SiteInfo>{};
  for (final e in entries) {
    final site = siteForEntry(e);
    byKey.putIfAbsent(site.key, () => []).add(e);
    siteByKey[site.key] = site;
  }
  final groups = byKey.entries
      .map((kv) => SiteGroup(siteByKey[kv.key]!, kv.value))
      .toList();
  groups.sort((a, b) {
    if (a.entries.length != b.entries.length) {
      return b.entries.length.compareTo(a.entries.length);
    }
    return a.site.name.compareTo(b.site.name);
  });
  return groups;
}
