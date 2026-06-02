-- Track B 2단계: 사기 예측 모델 학습 (BigQuery ML, 로지스틱 회귀 베이스라인)
-- auto_class_weights=TRUE 로 0.12% 극불균형 보정.
-- train split(2013~2017)만 학습. split 컬럼은 피처에서 제외.

CREATE OR REPLACE MODEL `card-payment-analysis.card_raw.fraud_lr`
OPTIONS(
  model_type        = 'LOGISTIC_REG',
  input_label_cols  = ['is_fraud'],
  auto_class_weights = TRUE,
  data_split_method = 'NO_SPLIT'
) AS
SELECT
  is_fraud,
  amount, is_online, use_chip, hour, dow, mcc, no_state
FROM `card-payment-analysis.card_raw.fraud_features`
WHERE split = 'train';
