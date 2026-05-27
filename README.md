# Card Payment Analysis

카드 결제를 양면 시장(회원=수요 ↔ 가맹점=공급, 거래=매칭)으로 보고,
모니터링 → 드릴다운 → 예측으로 이어지는 분석 체계를 만든다.
카드사 사업기획·운영(이상거래) 관점의 인사이트 도출이 목표.

## 데이터
- IBM 합성 신용카드 거래 24,386,900건 (1991~2020, Apache-2.0). **합성 데이터.**
- MCC 업종명: greggles/mcc-codes (ISO 18245 기반).
- 분석 환경: BigQuery (GoogleSQL), 프로젝트 `card-payment-analysis`, 데이터셋 `card_raw`.

## 구조
- `sql/staging/` — 적재·정제 파이프라인
- `sql/analysis/` — 분석 쿼리
- `sql/marts/` — 집계 마트
- `notebooks/`, `python_scripts/`, `results/` — 시각화·산출물

## BigQuery 객체 (card_raw)
- `transactions` — 분석용 타입 테이블
- `transactions_staging` — STRING 원본 백업
- `mcc_codes` — MCC 업종명 참조표
- `transactions_labeled` — transactions + 업종명 뷰
