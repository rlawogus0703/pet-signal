/// 목록용 미리보기 주소. 서버 경유 사진(`/photo`)에만 `size=thumb` 를 붙입니다.
/// 이미 `?n=2` 가 있으면 `&size=thumb` 로 이어 붙입니다.
String? photoThumbUrl(String? proxyUrl, [String? fallback]) {
  if (proxyUrl != null && proxyUrl.isNotEmpty) {
    final sep = proxyUrl.contains('?') ? '&' : '?';
    return '$proxyUrl${sep}size=thumb';
  }
  if (fallback != null && fallback.isNotEmpty) return fallback;
  return null;
}
