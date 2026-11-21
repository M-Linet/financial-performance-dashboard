"""
Generate a SYNTHETIC sample file with the exact schema of the Kaggle
"Financial Statements" dataset (rish1203/financial-statements).

Companies and numbers are fictional. The file exists so the repo can be
opened and refreshed end-to-end before you download the real data.

Usage:
    python scripts/make_sample_data.py            # writes data/sample/financial_statements_sample.csv
"""
from pathlib import Path
import numpy as np
import pandas as pd

OUT = Path(__file__).resolve().parents[1] / "data" / "sample" / "financial_statements_sample.csv"

# ticker, category, base revenue ($M), gross margin, ebitda margin, net margin, growth
COMPANIES = [
    ("NWTC", "IT",      42000, 0.62, 0.38, 0.24, 0.11),
    ("CRST", "FinTech",  9000, 0.48, 0.24, 0.14, 0.17),
    ("HRBR", "BANK",    31000, 0.95, 0.35, 0.18, 0.03),
    ("BLDR", "FOOD",    18000, 0.55, 0.42, 0.21, 0.04),
    ("VLTA", "ELEC",    14000, 0.36, 0.22, 0.06, 0.02),
    ("PKLG", "LOGI",    65000, 0.41, 0.12, 0.04, 0.15),
]
YEARS = range(2013, 2024)
INFLATION = {2013: 1.46, 2014: 1.62, 2015: 0.12, 2016: 1.26, 2017: 2.13, 2018: 2.44,
             2019: 1.81, 2020: 1.23, 2021: 4.70, 2022: 8.00, 2023: 4.12}


def main() -> None:
    rng = np.random.default_rng(42)
    rows = []
    for ticker, cat, base, gm, em, nm, g in COMPANIES:
        rev = base
        for y in YEARS:
            # one fictional company starts late and one has a loss year, to exercise edge cases
            if ticker == "CRST" and y < 2015:
                continue
            shock = rng.normal(0, 0.05)
            rev = rev * (1 + g + shock) if y > YEARS.start else rev
            gp = rev * (gm + rng.normal(0, 0.01))
            ebitda = rev * (em + rng.normal(0, 0.015))
            ni = rev * (nm + rng.normal(0, 0.01))
            if ticker == "VLTA" and y == 2020:
                ni = -0.05 * rev
            equity = rev * rng.uniform(0.35, 0.9)
            de = rng.uniform(0.2, 2.5) if cat != "BANK" else rng.uniform(4, 9)
            assets = equity * (1 + de) * rng.uniform(1.1, 1.4)
            shares = rng.uniform(800, 6000)
            cfo = ni * rng.uniform(1.1, 1.6)
            employees = int(rev / rng.uniform(0.25, 0.9) * 1)  # rev in $M -> employees
            rows.append({
                "Year": y,
                "Company ": ticker,  # trailing space reproduces the real file's header quirk
                "Category": cat,
                "Market Cap(in B USD)": round(rev * rng.uniform(2, 9) / 1000, 3),
                "Revenue": round(rev, 2),
                "Gross Profit": round(gp, 2),
                "Net Income": round(ni, 2),
                "Earning Per Share": round(ni / shares, 4),
                "EBITDA": round(ebitda, 2),
                "Share Holder Equity": round(equity, 2),
                "Cash Flow from Operating": round(cfo, 2),
                "Cash Flow from Investing": round(-rev * rng.uniform(0.04, 0.12), 2),
                "Cash Flow from Financial Activities": round(-rev * rng.uniform(0.02, 0.15), 2),
                "Current Ratio": round(rng.uniform(0.8, 2.8), 4),
                "Debt/Equity Ratio": round(de, 4),
                "ROE": round(ni / equity * 100, 4),
                "ROA": round(ni / assets * 100, 4),
                "ROI": round(ni / (equity * (1 + de)) * 100, 4),
                "Net Profit Margin": round(ni / rev * 100, 4),
                "Free Cash Flow per Share": round((cfo - rev * 0.05) / shares, 4),
                "Return on Tangible Equity": round(ni / (equity * 0.8) * 100, 4),
                "Number of Employees": employees,
                "Inflation Rate(in US)": INFLATION[y],
            })
    df = pd.DataFrame(rows)
    # one missing market cap, like the real file
    df.loc[df.sample(1, random_state=1).index, "Market Cap(in B USD)"] = np.nan
    OUT.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(OUT, index=False)
    print(f"Wrote {len(df)} rows -> {OUT}")


if __name__ == "__main__":
    main()
