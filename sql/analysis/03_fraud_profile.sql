-- 분석 #3: 사기 거래의 "전형" — 결제수단(채널) × 시간대 교차
-- 질문: 사기는 어떤 채널의 어떤 시간대에 집중되나? (#2의 업종 축에 채널·시간 축을 더해 프로파일 완성)
-- 윈도우: 2013~2019. 시간대는 4구간으로 묶어 가독성 확보.

WITH base AS (
  SELECT
    use_chip,
    CASE
      WHEN EXTRACT(HOUR FROM txn_datetime) BETWEEN 0  AND 5  THEN '0_새벽(0-5)'
      WHEN EXTRACT(HOUR FROM txn_datetime) BETWEEN 6  AND 11 THEN '1_오전(6-11)'
      WHEN EXTRACT(HOUR FROM txn_datetime) BETWEEN 12 AND 17 THEN '2_오후(12-17)'
      ELSE                                                       '3_저녁(18-23)'
    END AS time_band,
    is_fraud
  FROM `card-payment-analysis.card_raw.transactions`
  WHERE EXTRACT(YEAR FROM txn_datetime) BETWEEN 2013 AND 2019
)
SELECT
  use_chip,
  time_band,
  COUNT(*)                                              AS txns,
  COUNTIF(is_fraud)                                     AS fraud_count,
  ROUND(COUNTIF(is_fraud) / COUNT(*) * 100, 4)          AS fraud_rate,
  -- 전체 사기 중 이 (채널×시간대) 칸의 비중
  ROUND(COUNTIF(is_fraud) / SUM(COUNTIF(is_fraud)) OVER () * 100, 2) AS fraud_share
FROM base
GROUP BY use_chip, time_band
ORDER BY fraud_rate DESC;
