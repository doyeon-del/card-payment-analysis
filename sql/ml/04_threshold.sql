-- Track B 4단계: threshold별 precision-recall tradeoff (운영 관점)
-- ML.ROC_CURVE는 tp/fp/tn/fn을 threshold별로 준다. precision은 직접 계산.
-- 질문: "사기를 X% 잡으려면 오탐을 몇 건 감수해야 하나?" = 모니터링 알림 정책의 핵심.

SELECT
  ROUND(threshold, 4)                                   AS threshold,
  true_positives                                        AS tp,
  false_positives                                       AS fp,
  false_negatives                                       AS fn,
  ROUND(recall, 4)                                      AS recall,
  -- precision = tp / (tp + fp). 알림 1건이 진짜 사기일 확률.
  ROUND(SAFE_DIVIDE(true_positives, true_positives + false_positives), 4) AS precision,
  -- alerts_per_fraud = 사기 1건 잡으려 띄우는 총 알림 수 (운영 부담 직관 지표)
  ROUND(SAFE_DIVIDE(true_positives + false_positives, true_positives), 1) AS alerts_per_fraud
FROM ML.ROC_CURVE(
  MODEL `card-payment-analysis.card_raw.fraud_lr`,
  (
    SELECT is_fraud, amount, is_online, use_chip, hour, dow, mcc, no_state
    FROM `card-payment-analysis.card_raw.fraud_features`
    WHERE split = 'test'
  ),
  GENERATE_ARRAY(0.5, 0.95, 0.05)   -- threshold 후보
)
ORDER BY threshold;
