"""Windows(cp949) 콘솔에서도 출력 때문에 죽지 않도록 stdout/stderr 를 안전하게 설정."""

import sys


def make_console_safe() -> None:
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(errors="replace")  # type: ignore[attr-defined]
        except Exception:
            pass
