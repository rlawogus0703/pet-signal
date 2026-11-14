"""평가 그래프 (matplotlib). 한글 글꼴이 있으면 한글, 없으면 영어 라벨."""

from __future__ import annotations

from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib import font_manager  # noqa: E402

LABEL_KO = {
    "baseline_strict": "기존 조건 검색",
    "baseline_breed": "관대한 기존 검색",
    "baseline_region": "지역 둘러보기",
    "rule": "규칙만",
    "rule_text": "규칙+텍스트",
    "full": "규칙+텍스트+사진",
}
LABEL_EN = {
    "baseline_strict": "Baseline (exact filters)",
    "baseline_breed": "Baseline (normalized breed)",
    "baseline_region": "Region browse",
    "rule": "Rule only",
    "rule_text": "Rule+Text",
    "full": "Rule+Text+Image",
}
LINESTYLE = {"baseline_strict": "--", "baseline_breed": "-.", "baseline_region": ":"}
LEVEL_KO = {"easy": "쉬움", "medium": "보통", "hard": "어려움"}
COLORS = {"baseline_strict": "#616161", "baseline_breed": "#9e9e9e", "baseline_region": "#c7c7c7", "rule": "#90caf9", "rule_text": "#42a5f5", "full": "#1565c0"}


def _korean_font() -> bool:
    for name in ("Noto Sans CJK KR", "NanumGothic", "Gothic A1", "Malgun Gothic", "AppleGothic"):
        if any(f.name == name for f in font_manager.fontManager.ttflist):
            plt.rcParams["font.family"] = name
            plt.rcParams["axes.unicode_minus"] = False
            return True
    return False


def draw(summary: dict, curve: dict, out: Path) -> list[Path]:
    ko = _korean_font()
    lab = LABEL_KO if ko else LABEL_EN
    methods = list(LABEL_KO)
    paths = []

    # 1) 난이도별 Top-5
    fig, ax = plt.subplots(figsize=(9, 4.8))
    groups = ["overall", "easy", "medium", "hard"]
    gl = (["전체", "쉬움", "보통", "어려움"] if ko else ["All", "Easy", "Medium", "Hard"])
    bw = 0.14
    for i, m in enumerate(methods):
        vals = [(summary["overall"] if g == "overall" else summary["by_level"][g])[m]["top5"] * 100 for g in groups]
        xs = [k + (i - 2.5) * bw for k in range(len(groups))]
        bars = ax.bar(xs, vals, bw, label=lab[m], color=COLORS[m])
        for x, v in zip(xs, vals):
            ax.text(x, v + 1, f"{v:.0f}", ha="center", fontsize=7)
    ax.set_xticks(range(len(groups)), gl)
    ax.set_ylim(0, 122)
    ax.set_yticks(range(0, 101, 20))
    ax.set_ylabel("Top-5 정답률 (%)" if ko else "Top-5 hit rate (%)")
    ax.set_title("난이도별 Top-5: 정답 공고가 상위 5개 안에 든 비율" if ko else "Top-5 hit rate by difficulty")
    ax.legend(fontsize=8, ncol=3, loc="upper center")
    fig.tight_layout()
    p = out / "top5_by_level.png"
    fig.savefig(p, dpi=150)
    plt.close(fig)
    paths.append(p)

    # 2) 누적 Top-K 곡선
    fig, ax = plt.subplots(figsize=(8, 4.8))
    ks = list(range(1, 51))
    for m in methods:
        ax.plot(ks, [v * 100 for v in curve[m]], label=lab[m], color=COLORS[m], lw=2,
                ls=LINESTYLE.get(m, "-"))
    for k in (1, 5, 10):
        ax.axvline(k, color="#eee", lw=1, zorder=0)
    ax.set_xlabel("확인한 공고 수 K (상위 K개)" if ko else "K (top-K notices checked)")
    ax.set_ylabel("정답을 찾은 비율 (%)" if ko else "Hit rate (%)")
    ax.set_ylim(0, 102)
    ax.set_title("상위 K개 안에 정답 공고가 있을 확률 (전체 질의)" if ko else "Cumulative Top-K hit rate (all queries)")
    ax.legend(fontsize=8, loc="lower right")
    fig.tight_layout()
    p = out / "topk_curve.png"
    fig.savefig(p, dpi=150)
    plt.close(fig)
    paths.append(p)
    return paths
