-- Track A / A1: 일별 KPI 마트 (모니터링 단일 소스)
-- 모니터링·이상탐지(A3)·드릴다운(A4)·대시보드가 공통으로 참조하는 표준 테이블.
-- grain: 일별, 2013~2019. net_amount는 환불(음수) 포함 = 순매출 기준.

CREATE OR REPLACE TABLE `card-payment-analysis.card_raw.daily_kpi` AS
SELECT
  DATE(txn_datetime)                                AS dt,            -- 날짜(일 단위)
  COUNT(*)                                          AS txns,          -- 거래 건수
  ROUND(SUM(amount), 2)                             AS net_amount,    -- 순매출(환불 포함)
  ROUND(AVG(amount), 2)                             AS avg_ticket,    -- 객단가
  COUNT(DISTINCT user_id)                           AS active_users,  -- 활성 회원수
  -- 활성 카드수: card_id는 회원 내 순번(0~8)이라 고유 카드는 (user_id, card_id) 복합키로
  COUNT(DISTINCT FORMAT('%d-%d', user_id, card_id)) AS active_cards,
  COUNTIF(is_fraud)                                 AS fraud_count,   -- 사기 건수
  ROUND(COUNTIF(is_fraud) / COUNT(*) * 100, 4)      AS fraud_rate,    -- 사기율 %
  ROUND(COUNTIF(is_online) / COUNT(*) * 100, 2)     AS online_share,  -- 온라인 비중 %
  COUNTIF(amount < 0)                               AS refund_count   -- 환불(음수) 건수
FROM `card-payment-analysis.card_raw.transactions`
WHERE EXTRACT(YEAR FROM txn_datetime) BETWEEN 2013 AND 2019
GROUP BY dt
ORDER BY dt;
