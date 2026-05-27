-- 적재 & 정제 파이프라인 — card-payment-analysis.card_raw
-- 원본: IBM 합성 신용카드 거래 card_transaction.v1.csv (24,386,900건, 1991~2020)
-- [1],[3]의 적재는 CLI(bq load)로 수행했고, 재현을 위해 명령을 주석으로 남김.

-- [1] 로컬 CSV -> STRING 스테이징 (컬럼명에 공백/?가 있어 정제명으로 적재, 전부 STRING)
--   bq load --source_format=CSV --skip_leading_rows=1 --allow_quoted_newlines \
--     card_raw.transactions_staging card_transaction.v1.csv \
--     "user:STRING,card:STRING,year:STRING,month:STRING,day:STRING,time:STRING,amount:STRING,\
--      use_chip:STRING,merchant_name:STRING,merchant_city:STRING,merchant_state:STRING,\
--      zip:STRING,mcc:STRING,errors:STRING,is_fraud:STRING"

-- [2] 타입 변환 테이블 (분석용)
CREATE OR REPLACE TABLE `card-payment-analysis.card_raw.transactions` AS
SELECT
  SAFE_CAST(user AS INT64)  AS user_id,
  SAFE_CAST(card AS INT64)  AS card_id,
  -- "$134.09" -> 134.09 (음수 환불 포함)
  SAFE_CAST(REPLACE(REPLACE(amount, '$', ''), ',', '') AS FLOAT64) AS amount,
  -- 연/월/일 + HH:MM -> DATETIME
  DATETIME(
    SAFE_CAST(year AS INT64), SAFE_CAST(month AS INT64), SAFE_CAST(day AS INT64),
    SAFE_CAST(SPLIT(time, ':')[OFFSET(0)] AS INT64),
    SAFE_CAST(SPLIT(time, ':')[OFFSET(1)] AS INT64), 0
  ) AS txn_datetime,
  use_chip,
  (use_chip = 'Online Transaction') AS is_online,
  merchant_name,                       -- 거대 정수 ID라 STRING 유지
  merchant_city,
  NULLIF(merchant_state, '') AS merchant_state,
  NULLIF(zip, '')            AS zip,
  SAFE_CAST(mcc AS INT64)    AS mcc,
  NULLIF(errors, '')         AS errors,
  (is_fraud = 'Yes')         AS is_fraud
FROM `card-payment-analysis.card_raw.transactions_staging`;

-- [3] MCC 업종명 참조표 적재 (공개표: greggles/mcc-codes, ISO 18245 기반, 981행)
--   curl -sL -o mcc_codes.csv https://raw.githubusercontent.com/greggles/mcc-codes/main/mcc_codes.csv
--   bq load --source_format=CSV --skip_leading_rows=1 --allow_quoted_newlines --replace \
--     card_raw.mcc_codes mcc_codes.csv \
--     "mcc:STRING,edited_description:STRING,combined_description:STRING,\
--      usda_description:STRING,irs_description:STRING,irs_reportable:STRING"

-- [4] 라벨 뷰: 거래 + 업종명 (업종 분석은 이 뷰 사용)
CREATE OR REPLACE VIEW `card-payment-analysis.card_raw.transactions_labeled` AS
SELECT t.*, r.edited_description AS mcc_desc
FROM `card-payment-analysis.card_raw.transactions` t
LEFT JOIN `card-payment-analysis.card_raw.mcc_codes` r
  ON t.mcc = SAFE_CAST(r.mcc AS INT64);
