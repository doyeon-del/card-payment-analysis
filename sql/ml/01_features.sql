-- Track B 1단계: 사기 예측 피처/라벨 뷰
-- 라벨 = is_fraud. 피처는 "거래 시점에 알 수 있는 것"만 (누수 방지).
-- 시간 기반 분할: 2013~2017 train / 2018~2019 test (과거로 학습 → 미래 예측).

CREATE OR REPLACE VIEW `card-payment-analysis.card_raw.fraud_features` AS
SELECT
  is_fraud,                                       -- 라벨 (BOOLEAN)
  -- ----- 거래 시점 피처 -----
  amount,                                         -- 금액(환불 음수 포함)
  is_online,                                      -- 온라인 여부 (강신호)
  use_chip,                                       -- 결제수단 (Swipe/Chip/Online)
  EXTRACT(HOUR FROM txn_datetime)      AS hour,   -- 시간대 (낮에 사기↑)
  EXTRACT(DAYOFWEEK FROM txn_datetime) AS dow,    -- 요일 (1=일)
  CAST(mcc AS STRING)                  AS mcc,    -- 업종코드: STRING이면 BQML이 범주형 처리
  (merchant_state IS NULL)             AS no_state, -- 가맹점 위치 결측(온라인 성격)
  -- ----- 분할 -----
  IF(EXTRACT(YEAR FROM txn_datetime) <= 2017, 'train', 'test') AS split
FROM `card-payment-analysis.card_raw.transactions`
WHERE EXTRACT(YEAR FROM txn_datetime) BETWEEN 2013 AND 2019;
-- 제외: errors(Bad PIN 등) = 사후 정보 냄새 → 누수 위험으로 일단 미사용
