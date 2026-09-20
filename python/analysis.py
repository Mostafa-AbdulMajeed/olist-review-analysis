"""
Olist analysis — Stage 4 (Python half): statistical backup for the
SQL findings, plus the charts that go in the writeup.

Why Python here at all, given SQL already answered the question:
SQL tells you the averages differ. It doesn't tell you whether that
difference is bigger than you'd expect from noise alone. That's the
one thing this script adds — the significance check — plus the plots
that make the finding legible to a non-technical reader.

Run:  python analysis.py
Requires a local Postgres reachable with the connection string below,
and Stage 3 (03_prepare.sql) already run so analysis_base exists.
"""

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from scipy import stats
import psycopg2

# ---- connection -------------------------------------------------
# Adjust to match your setup (matches the DB name used in 01_load.sql)
CONN_STRING = "dbname=olist user=postgres password=postgres host=localhost port=5432"

OUT_DIR = "charts"

import os
os.makedirs(OUT_DIR, exist_ok=True)

def load_data():
    with psycopg2.connect(CONN_STRING) as conn:
        df = pd.read_sql("SELECT * FROM analysis_base;", conn)
    return df


def headline_test(df: pd.DataFrame):
    """Is the late-vs-on-time review score gap real, or noise?"""
    late = df.loc[df.was_late, "review_score"]
    on_time = df.loc[~df.was_late, "review_score"]

    t_stat, p_value = stats.ttest_ind(late, on_time, equal_var=False)

    print("=== Headline: late delivery vs review score ===")
    print(f"On-time orders  (n={len(on_time):,}): mean score = {on_time.mean():.2f}")
    print(f"Late orders     (n={len(late):,}): mean score = {late.mean():.2f}")
    print(f"Difference: {on_time.mean() - late.mean():.2f} points")
    print(f"t-statistic = {t_stat:.2f}, p-value = {p_value:.2e}")
    if p_value < 0.05:
        print("-> Statistically significant: this is not noise.")
    else:
        print("-> Not statistically significant at the 5% level — treat with caution.")
    print()


def correlation_check(df: pd.DataFrame):
    """Simple linear correlation, delay severity vs score."""
    clean = df.dropna(subset=["delay_days", "review_score"])
    r, p = stats.pearsonr(clean["delay_days"], clean["review_score"])
    print("=== Correlation: delay_days vs review_score ===")
    print(f"Pearson r = {r:.3f}, p-value = {p:.2e}")
    print("(Negative r confirms: more days late -> lower score.)\n")


def make_charts(df: pd.DataFrame):
    sns.set_style("whitegrid")

    # 1. Review score distribution
    plt.figure(figsize=(7, 4))
    sns.countplot(x="review_score", data=df, color="steelblue")
    plt.title("Review score distribution")
    plt.tight_layout()
    plt.savefig(f"{OUT_DIR}/01_review_score_distribution.png", dpi=150)
    plt.close()

    # 2. Review score by late vs on-time
    plt.figure(figsize=(6, 4))
    sns.boxplot(x="was_late", y="review_score", data=df)
    plt.xticks([0, 1], ["On time", "Late"])
    plt.title("Review score: on-time vs late deliveries")
    plt.tight_layout()
    plt.savefig(f"{OUT_DIR}/02_score_by_lateness.png", dpi=150)
    plt.close()

    # 3. Avg review score by delay bucket
    bucket_order = ["on_time", "late_1_3_days", "late_4_7_days", "late_8plus_days"]
    df["delay_bucket"] = pd.cut(
        df["delay_days"],
        bins=[-float("inf"), 0, 3, 7, float("inf")],
        labels=bucket_order,
    )
    bucket_means = df.groupby("delay_bucket", observed=True)["review_score"].mean().reindex(bucket_order)
    plt.figure(figsize=(7, 4))
    bucket_means.plot(kind="bar", color="darkorange")
    plt.ylabel("Avg review score")
    plt.title("Review score by delay severity")
    plt.xticks(rotation=20)
    plt.tight_layout()
    plt.savefig(f"{OUT_DIR}/03_score_by_delay_bucket.png", dpi=150)
    plt.close()

    # 4. Delay stage decomposition: seller handling vs carrier transit
    stage_means = (
        df.groupby("was_late")[["seller_handling_days", "carrier_transit_days"]]
        .mean()
    )
    stage_means.index = ["On time", "Late"]
    plt.figure(figsize=(7, 4))
    stage_means.plot(kind="bar")
    plt.ylabel("Avg days")
    plt.title("Where does the delay come from: seller handling vs carrier transit")
    plt.xticks(rotation=0)
    plt.tight_layout()
    plt.savefig(f"{OUT_DIR}/04_delay_stage_decomposition.png", dpi=150)
    plt.close()

    # 5. Worst states by late rate (min volume filter)
    state_stats = (
        df.groupby("customer_state")
        .agg(n_orders=("order_id", "count"), pct_late=("was_late", "mean"))
        .query("n_orders >= 100")
        .sort_values("pct_late", ascending=False)
        .head(10)
    )
    plt.figure(figsize=(8, 4))
    (state_stats["pct_late"] * 100).plot(kind="bar", color="firebrick")
    plt.ylabel("% orders late")
    plt.title("Worst states by late-delivery rate (min 100 orders)")
    plt.tight_layout()
    plt.savefig(f"{OUT_DIR}/05_worst_states_late_rate.png", dpi=150)
    plt.close()

    print(f"Charts saved to ./{OUT_DIR}/\n")


def main():
    df = load_data()
    print(f"Loaded {len(df):,} rows from analysis_base.\n")
    headline_test(df)
    correlation_check(df)
    make_charts(df)


if __name__ == "__main__":
    main()
