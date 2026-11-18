#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API_BASE="${1:-${API_BASE_URL:-}}"
if [[ -z "${API_BASE}" ]]; then
  echo "사용법: $0 <API_BASE_URL>" >&2
  echo "예: $0 https://pet-signal-api.onrender.com" >&2
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter 를 PATH 에서 찾지 못했습니다." >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "git 이 필요합니다." >&2
  exit 1
fi

cd "${ROOT}/web"
flutter pub get
flutter build web --release \
  --base-href /pet-signal/ \
  --no-web-resources-cdn \
  --dart-define="API_BASE_URL=${API_BASE}"

BUILD="${ROOT}/web/build/web"
if [[ ! -f "${BUILD}/index.html" ]]; then
  echo "빌드 결과가 없습니다: ${BUILD}/index.html" >&2
  exit 1
fi

ORIGIN="$(git -C "${ROOT}" remote get-url origin)"
NAME="$(git -C "${ROOT}" config user.name || true)"
EMAIL="$(git -C "${ROOT}" config user.email || true)"
if [[ -z "${NAME}" ]]; then NAME="$(git -C "${ROOT}" log -1 --format='%an')"; fi
if [[ -z "${EMAIL}" ]]; then EMAIL="$(git -C "${ROOT}" log -1 --format='%ae')"; fi

TMP="$(mktemp -d)"
cleanup() { rm -rf "${TMP}"; }
trap cleanup EXIT

cp -a "${BUILD}/." "${TMP}/"
touch "${TMP}/.nojekyll"

git -C "${TMP}" init
git -C "${TMP}" checkout -b gh-pages
git -C "${TMP}" config user.name "${NAME}"
git -C "${TMP}" config user.email "${EMAIL}"
git -C "${TMP}" add -A
git -C "${TMP}" commit -m "Deploy Flutter web (API_BASE_URL set at build time)"
git -C "${TMP}" remote add origin "${ORIGIN}"
git -C "${TMP}" push -f origin gh-pages

echo "올렸습니다. Pages 원본이 gh-pages / (root) 인지 확인하세요."
echo "주소: https://rlawogus0703.github.io/pet-signal/"
