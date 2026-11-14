"""테스트 중에는 스케줄러·시작 시 수집이 돌지 않게 합니다 (공공 API/외부 DB 호출 방지)."""

import os

os.environ["COLLECT_ON_STARTUP"] = "false"
os.environ["ENABLE_SCHEDULER"] = "false"
# 테스트는 로컬 SQLite 를 씁니다. 셸에 DATABASE_URL 이 있어도 덮어쓰지 않도록
# 개별 테스트가 필요할 때 monkeypatch 합니다.
os.environ.pop("DATABASE_URL", None)
os.environ.pop("ADMIN_API_KEY", None)
