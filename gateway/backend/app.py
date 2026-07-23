from flask import Flask, request, jsonify
import re

app = Flask(__name__)

# 프롬프트 인젝션/탈옥 시도 차단 패턴 (데모용 최소 세트)
BLOCK_PATTERNS = [
    r"ignore\s+(all\s+)?previous",
    r"disregard\s+(the\s+)?instructions",
    r"system\s+prompt",
    r"지시.{0,4}무시",
    r"이전\s*지시",
    r"탈옥",
    r"jailbreak",
]


@app.post("/v1/infer")
def infer():
    data = request.get_json(silent=True) or {}
    prompt = str(data.get("prompt", ""))
    low = prompt.lower()
    for pat in BLOCK_PATTERNS:
        if re.search(pat, low):
            return jsonify(error="prompt blocked by input filter", matched=pat), 400
    return jsonify(
        answer="[모의 추론 결과] 정상 요청으로 처리되었습니다.",
        prompt=prompt,
    )


@app.get("/healthz")
def healthz():
    return jsonify(status="ok")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
