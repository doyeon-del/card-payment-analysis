-- 분석 #2: 사기 드릴다운 — 업종(MCC)별 사기 집중도
-- 질문: 사기는 어느 업종에 집중되는가? 사기율 + 전체 사기 중 비중/순위로 본다.
-- 윈도우: 2013~2019(성숙 구간). 소표본 노이즈 방지로 거래 1만 건 이상 업종만.

SELECT
  mcc,
  mcc_desc,
  COUNT(*)                                              AS txns,
  COUNTIF(is_fraud)                                     AS fraud_count,
  ROUND(COUNTIF(is_fraud) / COUNT(*) * 100, 4)          AS fraud_rate,
  -- fraud_share: 전체 사기건수 대비 이 업종 비중. SUM(...) OVER () = 모든 업종 사기합
  ROUND(COUNTIF(is_fraud) / SUM(COUNTIF(is_fraud)) OVER () * 100, 2) AS fraud_share,
  -- fraud_rank: 사기율 높은 순 순위
  RANK() OVER (ORDER BY COUNTIF(is_fraud) / COUNT(*) DESC)           AS fraud_rank
FROM `card-payment-analysis.card_raw.transactions_labeled`
WHERE EXTRACT(YEAR FROM txn_datetime) BETWEEN 2013 AND 2019
GROUP BY mcc, mcc_desc
HAVING COUNT(*) >= 10000      -- 거래 1만 건 미만 업종 제외
ORDER BY fraud_rate DESC;
