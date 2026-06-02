-- Track B 5단계: 비교 모델 — Boosted Tree (XGBoost) 분류기
-- LR 베이스라인과 동일 피처·동일 split. 비선형 상호작용(예: online×hour×mcc)을
-- 잡아 AUC 개선을 노린다. auto_class_weights로 0.12% 불균형 보정.

CREATE OR REPLACE MODEL `card-payment-analysis.card_raw.fraud_bt`
OPTIONS(
  model_type         = 'BOOSTED_TREE_CLASSIFIER',
  input_label_cols   = ['is_fraud'],
  auto_class_weights  = TRUE,
  data_split_method  = 'NO_SPLIT',
  max_iterations     = 30,
  early_stop         = TRUE,
  learn_rate         = 0.2
) AS
SELECT
  is_fraud,
  amount, is_online, use_chip, hour, dow, mcc, no_state
FROM `card-payment-analysis.card_raw.fraud_features`
WHERE split = 'train';
