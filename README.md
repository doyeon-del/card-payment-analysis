# Card Payment Analysis

카드 결제를 양면 시장(회원=수요 ↔ 가맹점=공급, 거래=매칭)으로 보고,
모니터링 → 드릴다운 → 예측으로 이어지는 분석 체계를 만든다.
카드사 사업기획·운영(이상거래) 관점의 인사이트 도출이 목표.

## 데이터
- IBM 합성 신용카드 거래 24,386,900건 (1991~2020, Apache-2.0). **합성 데이터.**
- MCC 업종명: greggles/mcc-codes (ISO 18245 기반).
- 분석 환경: BigQuery (GoogleSQL), 프로젝트 `card-payment-analysis`, 데이터셋 `card_raw`.
- 분석 윈도우: 거래량·사기 라벨이 안정적인 2013~2019 구간.

## 분석 체계
헬스체크 지표로 전체를 보고(모니터링), 이상이 잡히면 차원을 쪼개 원인을 좁히고(드릴다운),
그 신호를 모델로 점수화한다(예측). 단발 EDA가 아니라 재사용 가능한 마트·뷰로 자산화하는 것이 목표.

| 층위 | 산출물 | 위치 |
|---|---|---|
| 모니터링 | 월별·일별 KPI (거래량·사기율·온라인비중·환불) | `sql/analysis/01`, `sql/marts/daily_kpi` |
| 드릴다운 | 업종(MCC)·채널×시간대 사기 프로파일 | `sql/analysis/02`, `sql/analysis/03` |
| 예측 | 사기 이진분류 (BQML + sklearn) | `sql/ml/`, `python_scripts/` |

## 주요 결과
- **월별 모니터링 (EDA #1).** 거래량·평균 객단가는 평탄, 월별 사기율은 0~0.08% 범위에서 출렁인다.
  합성 데이터라 뚜렷한 계절성은 없고, 사기 라벨이 특정 월에 몰리는 형태.
- **업종 드릴다운 (EDA #2).** 사기율 1위는 호텔 체인(윈덤/힐튼/메리어트 약 1.0~1.1%)과
  디지털 굿즈(0.78%) 등 **소액·비대면 업종**. 사기율(rate)과 사기 건수 비중(share)을 분리해서 봐야
  "비율은 높지만 양은 적은" 업종과 "비율은 낮아도 양이 많은" 업종이 갈린다.
- **채널×시간대 프로파일 (EDA #3).** **온라인 결제의 오전·오후 두 칸이 전체 사기의 약 54%**
  (온라인×오전 27.9% + 온라인×오후 26.4%). 칩·스와이프 대면 채널은 같은 시간대라도 사기율이
  훨씬 낮다. 사기 프로파일 종합 = 비대면 × 한낮 × 호텔/디지털/의류 업종.

## 구조
- `sql/staging/` — 적재·정제 파이프라인
- `sql/analysis/` — 분석 쿼리 (EDA·드릴다운)
- `sql/marts/` — 집계 마트 (`daily_kpi`)
- `sql/ml/` — 사기 예측 모델: 피처→학습→평가→threshold→비교 (BQML)
- `python_scripts/` — sklearn 재모델링·평가 (`fraud_model.py`)
- `results/tables/`, `results/figures/` — 결과 CSV·그래프

## BigQuery 객체 (card_raw)
- `transactions` — 분석용 타입 테이블 (2,438만)
- `transactions_staging` — STRING 원본 백업
- `mcc_codes` — MCC 업종명 참조표
- `transactions_labeled` — transactions + 업종명 뷰
- `daily_kpi` — 일별 KPI 마트 (모니터링 단일 소스)
- `fraud_features` — 사기 예측 피처/라벨 뷰 (time-split 포함)
- `fraud_lr` / `fraud_bt` — 사기 예측 모델 (로지스틱 회귀 / 부스팅 트리)
- `ml_sample` — Python 모델링용 균일 10% 샘플 (사기 비율 보존)

## 사기 예측 (Track B)
극불균형(사기 0.13%) 이진분류. 누수 방지 time-split(2013–17 train / 2018–19 test).
- **BQML**: LR 베이스라인 ROC-AUC 0.66 → Boosted Tree 0.76 (log_loss 0.69→0.23).
- **Python(sklearn)**: HistGBT ROC-AUC 0.825, **PR-AUC 0.013** — 극불균형에서 ROC-AUC는 낙관적, PR-AUC/precision@K가 실질 성능. 위험순위 상위 0.1%만 검토해도 사기 농도 base 대비 28.5배.
- 피처 중요도: mcc(업종) > use_chip(채널) > amount > hour. `is_online`은 use_chip와 중복(다중공선성).
- 운영 함의: threshold 고정이 아니라 "알림 예산(top-K) 안에서 recall 극대화"로 접근.

## 진행 현황
- [x] 적재·정제 파이프라인 + MCC 매핑
- [x] 모니터링 KPI (월별·일별 마트)
- [x] 드릴다운 (업종·채널×시간대)
- [x] 사기 예측 (BQML + sklearn)
- [ ] 이상탐지 baseline — 일별 KPI 이탈 자동 감지 (이동평균·z-score)
- [ ] 드릴다운 자동화 + 지표 사전 문서
- [ ] 모니터링 대시보드 / 종합 리포트
