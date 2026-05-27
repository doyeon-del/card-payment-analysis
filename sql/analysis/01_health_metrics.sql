--- 목표: 결제 시장 "모니터링"의 토대 = 월별 핵심 지표 한 장. (성숙 구간 2013~2019)

--- 만들 출력 칼럼: 월, 거래건수, 순거래액, 객단가, 활성카드 수, 사기 건수, 사기율


--- 1. 순거래액에 환불(음수 amount)을 포함할까?

---- amount 관련 연산 진행 

select DATE_TRUNC(DATE(txn_datetime), MONTH) as month, 
count(*) as txns, 
sum(amount) as sum_amount, --- sum_amount는 환불 포함 = 순매출 기준
avg(amount) as avg_amount,
count(distinct user_id) as active_users, 
countif(is_fraud) as fraud_count, 
round(countif(is_fraud) / count(*) * 100, 4) as fraud_rate
from `card-payment-analysis.card_raw.transactions`
where EXTRACT(YEAR from txn_datetime) between 2013 and 2019
group by month
order by month;



---- 2. 



