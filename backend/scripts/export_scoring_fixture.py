"""서버 점수 기준값을 웹 테스트용 JSON 으로 내보내기: python -m scripts.export_scoring_fixture"""

import json
from pathlib import Path

from app.ai.scoring_cases import compute_cases

OUT = Path(__file__).resolve().parents[2] / "web" / "test" / "fixtures" / "scoring_cases.json"


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(compute_cases(), ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
