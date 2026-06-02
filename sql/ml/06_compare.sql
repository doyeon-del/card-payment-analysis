-- Track B 6단계: 두 모델 비교 (LR 베이스라인 vs Boosted Tree)
-- 동일 test(2018~2019)에서 ML.EVALUATE. 불균형이라 roc_auc를 1순위로 본다.

SELECT 'LR_baseline'  AS model, * FROM ML.EVALUATE(
  MODEL `card-payment-analysis.card_raw.fraud_lr`,
  (SELECT is_fraud, amount, is_online, use_chip, hour, dow, mcc, no_state
   FROM `card-payment-analysis.card_raw.fraud_features` WHERE split = 'test'))
UNION ALL
SELECT 'BoostedTree' AS model, * FROM ML.EVALUATE(
  MODEL `card-payment-analysis.card_raw.fraud_bt`,
  (SELECT is_fraud, amount, is_online, use_chip, hour, dow, mcc, no_state
   FROM `card-payment-analysis.card_raw.fraud_features` WHERE split = 'test'))
ORDER BY model;
