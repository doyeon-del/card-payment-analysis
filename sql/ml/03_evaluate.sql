-- Track B 3단계: 사기 예측 모델 평가 (test = 2018~2019, 미래 구간)
-- 극불균형(0.13%)이라 accuracy는 무의미 → roc_auc / precision / recall 중심.
-- ML.EVALUATE의 precision·recall은 기본 threshold 0.5 기준값임(참고용).

SELECT *
FROM ML.EVALUATE(
  MODEL `card-payment-analysis.card_raw.fraud_lr`,
  (
    SELECT is_fraud, amount, is_online, use_chip, hour, dow, mcc, no_state
    FROM `card-payment-analysis.card_raw.fraud_features`
    WHERE split = 'test'
  )
);
