String? photoThumbUrl(String? proxyUrl, [String? fallback]) {
  if (proxyUrl != null && proxyUrl.isNotEmpty) {
    final sep = proxyUrl.contains('?') ? '&' : '?';
    return '$proxyUrl${sep}size=thumb';
  }
  if (fallback != null && fallback.isNotEmpty) return fallback;
  return null;
}
