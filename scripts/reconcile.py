"""
Reconciliation script: re-implements the Power Query shaping and the core
DAX measures in pandas, so you can check the dashboard's numbers against an
independent calculation (the same idea as tying out a report to the ledger).

Usage:
    python scripts/reconcile.py                                   # uses the synthetic sample
    python scripts/reconcile.py "data/raw/Financial Statements.csv"
    python scripts/reconcile.py <csv> --company AAPL --year 2022  # one card's worth of KPIs

Outputs (in scripts/output/, git-ignored):
    expected_by_year.csv          -> compare with the EVALUATE in dax/measures.dax
    expected_by_company_year.csv  -> compare with the Balance Sheet matrix
"""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CSV = ROOT / "data" / "sample" / "financial_statements_sample.csv"
OUT_DIR = ROOT / "scripts" / "output"

RENAME = {
    "Market Cap(in B USD)": "MarketCapB", "Gross Profit": "GrossProfit", "Net Income": "NetIncome",
    "Earning Per Share": "EPS", "Share Holder Equity": "ShareholderEquity",
    "Cash Flow from Operating": "CFO", "Cash Flow from Investing": "CFI",
    "Cash Flow from Financial Activities": "CFF", "Current Ratio": "CurrentRatio",
    "Debt/Equity Ratio": "DebtToEquity", "Net Profit Margin": "NetProfitMargin",
    "Free Cash Flow per Share": "FCFPerShare", "Return on Tangible Equity": "ROTE",
    "Number of Employees": "Employees", "Inflation Rate(in US)": "InflationRate",
}
PCT_COLS = ["ROE", "ROA", "ROI", "NetProfitMargin", "ROTE", "InflationRate"]


def stage(path: Path, ratios_are_percent: bool = True) -> pd.DataFrame:
    """Mirror of powerquery/01_stg_Financials.pq"""
    df = pd.read_csv(path)
    df.columns = [c.strip() for c in df.columns]
    df = df.rename(columns=RENAME)
    df["Company"] = df["Company"].astype(str).str.strip().str.upper()
    df["Category"] = df["Category"].astype(str).str.strip().str.upper()
    num_cols = [c for c in df.columns if c not in ("Company", "Category")]
    for c in num_cols:
        df[c] = pd.to_numeric(df[c], errors="coerce")
    if ratios_are_percent:
        for c in PCT_COLS:
            if c in df:
                df[c] = df[c] / 100
    # data-quality rules (mirror of stg_Financials)
    placeholder = df["EBITDA"].abs().le(1) & df["Revenue"].gt(1000)
    df.loc[placeholder, "EBITDA"] = np.nan
    df.loc[df["Category"].eq("BANK"), "CurrentRatio"] = np.nan
    df = df.drop(columns=["FCFPerShare"], errors="ignore")
    df = df.dropna(subset=["Company", "Year"]).drop_duplicates(["Company", "Year"])
    df["Year"] = df["Year"].astype(int)
    return df


def shape(stg: pd.DataFrame) -> pd.DataFrame:
    """Mirror of the fact-table derivations (04, 06, 07)."""
    d = stg.copy()
    d["CostOfRevenue"] = d["Revenue"] - d["GrossProfit"]
    d["OperatingExpenses"] = d["GrossProfit"] - d["EBITDA"]
    d["BelowEBITDA"] = d["EBITDA"] - d["NetIncome"]
    d["UnallocatedCosts"] = np.where(d["EBITDA"].isna(), d["GrossProfit"] - d["NetIncome"], np.nan)
    d["SharesOutstanding"] = np.where(d["EPS"].fillna(0) != 0, d["NetIncome"] / d["EPS"], np.nan)
    d["TotalDebt"] = d["DebtToEquity"] * d["ShareholderEquity"]
    assets = np.where(d["ROA"].abs() >= 0.0005, d["NetIncome"] / d["ROA"], np.nan)
    d["TotalAssets"] = np.where(assets > 0, assets, np.nan)
    d["OtherLiabilities"] = d["TotalAssets"] - d["ShareholderEquity"] - d["TotalDebt"]
    d["NetCashFlow"] = d[["CFO", "CFI", "CFF"]].sum(axis=1, min_count=1)
    return d


def by_year(d: pd.DataFrame) -> pd.DataFrame:
    """Mirror of the EVALUATE query at the bottom of dax/measures.dax."""
    g = d.groupby("Year").agg(
        Revenue=("Revenue", "sum"), GrossProfit=("GrossProfit", "sum"),
        OperatingIncome=("EBITDA", "sum"), NetIncome=("NetIncome", "sum"),
        CurrentRatio=("CurrentRatio", "mean"), Debt=("TotalDebt", "sum"),
        Equity=("ShareholderEquity", "sum"),
    )
    g["GrossMarginPct"] = g["GrossProfit"] / g["Revenue"]
    g["RevenueYoYPct"] = g["Revenue"].pct_change()
    # like-for-like: companies present in both years
    piv = d.pivot_table(index="Company", columns="Year", values="Revenue", aggfunc="sum")
    lfl = {}
    years = sorted(piv.columns)
    for prev, cur in zip(years, years[1:]):
        both = piv[[prev, cur]].dropna()
        lfl[cur] = both[cur].sum() / both[prev].sum() - 1 if len(both) else np.nan
    g["RevenueYoYPct_LFL"] = pd.Series(lfl)
    g["DebtToEquity"] = g["Debt"] / g["Equity"]
    return g.drop(columns=["Debt", "Equity"]).round(4)


def by_company_year(d: pd.DataFrame) -> pd.DataFrame:
    cols = ["Company", "Category", "Year", "Revenue", "GrossProfit", "EBITDA", "NetIncome",
            "ShareholderEquity", "TotalDebt", "TotalAssets", "OtherLiabilities",
            "CurrentRatio", "DebtToEquity", "CFO", "CFI", "CFF"]
    out = d[cols].sort_values(["Company", "Year"]).copy()
    out["GrossMarginPct"] = out["GrossProfit"] / out["Revenue"]
    out["NetMarginPct"] = out["NetIncome"] / out["Revenue"]
    out["RevenueYoYPct"] = out.groupby("Company")["Revenue"].pct_change()
    return out.round(4)


def checks(d: pd.DataFrame) -> list[str]:
    """Data-quality checks finance would want before the numbers go to leadership."""
    msgs = []
    parts = d[["CostOfRevenue", "OperatingExpenses", "BelowEBITDA", "UnallocatedCosts"]].sum(axis=1, min_count=1)
    bridge = d["Revenue"] - parts - d["NetIncome"]
    msgs.append(f"P&L bridge ties to Net Income: {np.allclose(bridge.dropna(), 0, atol=1e-6)}")
    msgs.append(f"Rows: {len(d)} | companies: {d['Company'].nunique()} | years: {d['Year'].min()}-{d['Year'].max()}")
    neg_gp = d[d["GrossProfit"] > d["Revenue"]]
    msgs.append(f"Rows with Gross Profit > Revenue: {len(neg_gp)}")
    msgs.append(f"Rows with no derived total assets (ROA~0 or sign mismatch): {d['TotalAssets'].isna().sum()}")
    msgs.append(f"Missing Market Cap: {d['MarketCapB'].isna().sum()}")
    msgs.append(f"EBITDA placeholders blanked: {d['EBITDA'].isna().sum()} | current ratio blanked (banks): {d['CurrentRatio'].isna().sum()}")
    counts = d.groupby("Year")["Company"].nunique()
    full = counts[counts >= 0.8 * counts.max()].index.max()
    msgs.append(f"Companies per year: {counts.to_dict()} -> latest full year = {full}")
    return msgs


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("csv", nargs="?", default=str(DEFAULT_CSV))
    ap.add_argument("--company")
    ap.add_argument("--year", type=int)
    ap.add_argument("--ratios-not-percent", action="store_true")
    a = ap.parse_args()

    d = shape(stage(Path(a.csv), ratios_are_percent=not a.ratios_not_percent))
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    y = by_year(d)
    cy = by_company_year(d)
    y.to_csv(OUT_DIR / "expected_by_year.csv")
    cy.to_csv(OUT_DIR / "expected_by_company_year.csv", index=False)

    print("\n".join(checks(d)))
    print("\nExpected values by year (compare with the DAX EVALUATE):")
    with pd.option_context("display.width", 160, "display.max_columns", 20):
        print(y)
        if a.company:
            sel = cy[cy["Company"] == a.company.upper()]
            if a.year:
                sel = sel[sel["Year"] == a.year]
            print(f"\n{a.company.upper()}:")
            print(sel.T if a.year else sel)
    print(f"\nCSV outputs written to {OUT_DIR}")


if __name__ == "__main__":
    main()
