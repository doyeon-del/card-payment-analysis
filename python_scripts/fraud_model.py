"""
Track B (Python 층): 사기 예측 모델링·평가
- 입력: data/ml_sample.csv (BigQuery fraud_features의 균일 10% 샘플, split 컬럼 포함)
- SQL(BQML)에서 만든 피처를 그대로 받아 sklearn으로 재모델링.
- 핵심 메시지: 0.13% 극불균형에서 ROC-AUC는 낙관적 → PR-AUC / precision@K로 검증.

산출물:
  results/tables/python_metrics.csv     모델별 ROC-AUC / PR-AUC / base-rate
  results/tables/python_precision_at_k.csv  알림예산(top-K)별 precision·recall·lift
  results/figures/pr_curve.png, roc_curve.png, lift_curve.png
  results/figures/perm_importance.png
"""
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from sklearn.compose import ColumnTransformer
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from sklearn.pipeline import Pipeline
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.inspection import permutation_importance
from sklearn.metrics import (roc_auc_score, average_precision_score,
                             roc_curve, precision_recall_curve)

ROOT = Path(__file__).resolve().parents[1]
FIG = ROOT / "results" / "figures"
TAB = ROOT / "results" / "tables"
FIG.mkdir(parents=True, exist_ok=True)
TAB.mkdir(parents=True, exist_ok=True)

# ---------- 1. 로드 & split ----------
df = pd.read_csv(ROOT / "data" / "ml_sample.csv")
# BigQuery BOOL은 CSV에서 'true'/'false' 문자열 → 정수로 변환
for c in ["is_fraud", "is_online", "no_state"]:
    df[c] = (df[c].astype(str).str.lower() == "true").astype(int)
train = df[df.split == "train"].copy()
test  = df[df.split == "test"].copy()

NUM = ["amount", "hour", "dow"]
BOOL = ["is_online", "no_state"]
CAT = ["use_chip", "mcc"]
FEATURES = NUM + BOOL + CAT

for d in (train, test):
    d[BOOL] = d[BOOL].astype(int)
    d["mcc"] = d["mcc"].astype(str)

Xtr, ytr = train[FEATURES], train["is_fraud"]
Xte, yte = test[FEATURES], test["is_fraud"]
base_rate = yte.mean()
print(f"train {len(train):,} (fraud {ytr.sum()}) | test {len(test):,} (fraud {yte.sum()}) | base rate {base_rate:.4%}")

# ---------- 2. 전처리 ----------
pre = ColumnTransformer([
    ("num", StandardScaler(), NUM),
    ("cat", OneHotEncoder(handle_unknown="ignore", min_frequency=50, sparse_output=False), CAT),
], remainder="passthrough")  # BOOL은 그대로 통과

# ---------- 3. 모델 2종 ----------
models = {
    "LogReg": Pipeline([("pre", pre),
                        ("clf", LogisticRegression(max_iter=1000, class_weight="balanced"))]),
    "HistGBT": Pipeline([("pre", pre),
                         ("clf", HistGradientBoostingClassifier(
                             max_iter=300, learning_rate=0.1,
                             class_weight="balanced", random_state=42))]),
}

rows, scores = [], {}
for name, pipe in models.items():
    pipe.fit(Xtr, ytr)
    p = pipe.predict_proba(Xte)[:, 1]
    scores[name] = p
    roc = roc_auc_score(yte, p)
    pr = average_precision_score(yte, p)           # PR-AUC = average precision
    rows.append({"model": name, "roc_auc": round(roc, 4),
                 "pr_auc": round(pr, 4), "pr_lift_vs_base": round(pr / base_rate, 1)})
    print(f"{name:8s}  ROC-AUC {roc:.4f}  PR-AUC {pr:.4f}  (base {base_rate:.4%})")

metrics = pd.DataFrame(rows)
metrics.to_csv(TAB / "python_metrics.csv", index=False)

best = metrics.sort_values("pr_auc", ascending=False).iloc[0]["model"]
pbest = scores[best]

# ---------- 4. precision@K (알림 예산 관점) ----------
# "분석가가 하루 상위 K건만 검토 가능"할 때 잡는 사기 비율 = 운영 현실 지표.
order = np.argsort(pbest)[::-1]
y_sorted = yte.values[order]
N, total_fraud = len(yte), int(yte.sum())
pk = []
for frac in [0.001, 0.005, 0.01, 0.02, 0.05, 0.10]:
    k = max(1, int(N * frac))
    caught = int(y_sorted[:k].sum())
    prec = caught / k
    rec = caught / total_fraud
    pk.append({"top_k_pct": frac * 100, "k_alerts": k, "fraud_caught": caught,
               "precision": round(prec, 4), "recall": round(rec, 4),
               "lift_vs_base": round(prec / base_rate, 1)})
pk_df = pd.DataFrame(pk)
pk_df.to_csv(TAB / "python_precision_at_k.csv", index=False)
print("\nprecision@K (best =", best, ")\n", pk_df.to_string(index=False))

# ---------- 5. 그림 ----------
# PR curve
plt.figure(figsize=(5, 4))
for name, p in scores.items():
    pr_p, pr_r, _ = precision_recall_curve(yte, p)
    plt.plot(pr_r, pr_p, label=f"{name} (AP={average_precision_score(yte,p):.3f})")
plt.axhline(base_rate, ls="--", c="gray", lw=1, label=f"base rate {base_rate:.3%}")
plt.xlabel("Recall"); plt.ylabel("Precision"); plt.title("PR curve (test 2018-19)")
plt.legend(); plt.tight_layout(); plt.savefig(FIG / "pr_curve.png", dpi=130); plt.close()

# ROC curve
plt.figure(figsize=(5, 4))
for name, p in scores.items():
    fpr, tpr, _ = roc_curve(yte, p)
    plt.plot(fpr, tpr, label=f"{name} (AUC={roc_auc_score(yte,p):.3f})")
plt.plot([0, 1], [0, 1], ls="--", c="gray", lw=1)
plt.xlabel("FPR"); plt.ylabel("TPR"); plt.title("ROC curve (test 2018-19)")
plt.legend(); plt.tight_layout(); plt.savefig(FIG / "roc_curve.png", dpi=130); plt.close()

# Lift / cumulative recall vs alert budget
plt.figure(figsize=(5, 4))
fracs = np.linspace(0.001, 0.20, 100)
cum_recall = [y_sorted[:max(1, int(N * f))].sum() / total_fraud for f in fracs]
plt.plot(fracs * 100, cum_recall, label=best)
plt.plot(fracs * 100, fracs, ls="--", c="gray", lw=1, label="random")
plt.xlabel("Alert budget: top-K reviewed (%)"); plt.ylabel("Fraud caught (recall)")
plt.title("Fraud recall vs alert budget"); plt.legend()
plt.tight_layout(); plt.savefig(FIG / "lift_curve.png", dpi=130); plt.close()

# ---------- 6. permutation importance (best 모델) ----------
bp = models[best]
imp = permutation_importance(bp, Xte, yte, scoring="average_precision",
                             n_repeats=5, random_state=42, n_jobs=-1)
imp_df = (pd.DataFrame({"feature": FEATURES, "importance": imp.importances_mean})
          .sort_values("importance", ascending=True))
plt.figure(figsize=(5, 4))
plt.barh(imp_df.feature, imp_df.importance)
plt.xlabel("PR-AUC drop (permutation)"); plt.title(f"Feature importance — {best}")
plt.tight_layout(); plt.savefig(FIG / "perm_importance.png", dpi=130); plt.close()
imp_df.sort_values("importance", ascending=False).to_csv(
    TAB / "python_feature_importance.csv", index=False)

print("\n완료. results/tables/*.csv, results/figures/*.png 저장됨.")
