-- Track A / A3: 이상탐지 baseline (일별 사기율 이탈 감지)
-- daily_kpi 위에 직전 30일(당일 제외) 이동평균·이동표준편차로 z-score를 구하고,
-- z >= 3(3σ) 이면서 거래량이 충분한(txns >= 1000) 날을 이상으로 표시한다.
--
-- 설계 메모:
--   - 직전 30일 = 당일을 뺀 ROWS BETWEEN 30 PRECEDING AND 1 PRECEDING.
--     당일이 자기 기준(평균·표준편차)을 오염시키지 않도록 trailing 윈도우만 사용.
--   - 거래량 가드(>=1000): 윤년(2016-02-29, 28건)처럼 거래가 극히 적은 날은
--     사기 몇 건만으로 사기율이 14%대까지 튀는 분모 아티팩트라 오탐(false positive)이 된다.
--     정상일이 ~4,800건이므로 1000 floor면 아티팩트만 걸러지고 진짜 이상일은 모두 남는다.
--   - 한계: 사기율이 쭉 0이던 구간은 표준편차가 0 → z가 NULL → 자동 제외된다.
--     "처음 사기가 터진 날"은 이 방식으로 못 잡는다(리포트에 명시할 baseline의 한계).
--   - 합성 데이터라 사기율 분포가 정규분포는 아니다(0인 날 많고 한쪽으로 치우침).
--     3σ는 절대 기준이 아니라 보수적 출발점으로 잡고, 잡힌 결과를 눈으로 검증해 채택했다.
--
-- 결과: 2013~2019 중 28일이 이상으로 표시됨 → results/tables/anomaly_days.csv

CREATE OR REPLACE VIEW `card-payment-analysis.card_raw.daily_kpi_anomaly` AS
WITH rolling AS (
  SELECT
    dt,
    txns,
    fraud_rate,
    AVG(fraud_rate)    OVER (ORDER BY dt ROWS BETWEEN 30 PRECEDING AND 1 PRECEDING) AS fr_mean,
    STDDEV(fraud_rate) OVER (ORDER BY dt ROWS BETWEEN 30 PRECEDING AND 1 PRECEDING) AS fr_std
  FROM `card-payment-analysis.card_raw.daily_kpi`
)
SELECT
  dt,
  txns,
  ROUND(fraud_rate, 4)                                AS fraud_rate,    -- 당일 사기율 %
  ROUND(fr_mean, 4)                                   AS fr_baseline,   -- 직전 30일 평균
  ROUND(SAFE_DIVIDE(fraud_rate - fr_mean, fr_std), 2) AS fraud_z,       -- 표준점수(σ 배수)
  (SAFE_DIVIDE(fraud_rate - fr_mean, fr_std) >= 3 AND txns >= 1000) AS is_anomaly
FROM rolling;

-- 이상일 추출 (results/tables/anomaly_days.csv):
-- SELECT dt, txns, fraud_rate, fr_baseline, fraud_z
-- FROM `card-payment-analysis.card_raw.daily_kpi_anomaly`
-- WHERE is_anomaly
-- ORDER BY fraud_z DESC;
