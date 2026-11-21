# Data dictionary

## Source

[Financial Statements dataset (Kaggle, rish1203)](https://www.kaggle.com/datasets/rish1203/financial-statements): annual figures compiled from 10-K reports for a set of large companies (tech, fintech, banking, food, utilities, logistics…), 2009–2023, 23 columns, one row per company-year. Currency values are **USD millions**; market cap is **USD billions**; ROE/ROA/ROI/Net Profit Margin are **percentages**.

Reference files maintained in this repo (`data/reference/`):

| File | Purpose |
|---|---|
| `company_master.csv` | Ticker → full name, sector, country. Edit freely; unknown tickers fall back to the ticker. |
| `pl_waterfall_steps.csv` | Order, label and sign of each P&L bridge step. |

## Column mapping (raw → model)

| Raw column | Model column | Table | Notes |
|---|---|---|---|
| Year | Year | all | Fiscal year (integer) |
| `Company ` (trailing space) | Company | all | Trimmed, upper-cased ticker |
| Category | Category | DimCompany | |
| Market Cap(in B USD) | MarketCapB | FactBalanceSheet | USD bn; one value missing in source |
| Revenue | Revenue | FactIncomeStatement | |
| Gross Profit | GrossProfit | FactIncomeStatement | |
| Net Income | NetIncome | FactIncomeStatement | |
| Earning Per Share | EPS | FactIncomeStatement | |
| EBITDA | EBITDA | FactIncomeStatement | Used as **operating income** |
| Share Holder Equity | ShareholderEquity | FactBalanceSheet | |
| Cash Flow from Operating / Investing / Financial Activities | CFO / CFI / CFF | FactCashFlow | |
| Current Ratio | CurrentRatio | FactBalanceSheet | Ratio only; no components |
| Debt/Equity Ratio | DebtToEquity | FactBalanceSheet | |
| ROE, ROA, ROI, Return on Tangible Equity | ROE, ROA, ROI, ROTE | FactBalanceSheet | ÷100 when `RatiosArePercent` |
| Net Profit Margin | NetProfitMargin | FactIncomeStatement | ÷100 |
| Free Cash Flow per Share | FCFPerShare | FactCashFlow | |
| Number of Employees | Employees | FactIncomeStatement | |
| Inflation Rate(in US) | US Inflation Rate | DimYear | ÷100 |

## Derived columns

| Column | Formula | Caveat |
|---|---|---|
| CostOfRevenue | Revenue − Gross Profit | ~0 for banks/insurers, where gross profit ≈ revenue |
| OperatingExpenses | Gross Profit − EBITDA | Includes R&D, SG&A, other operating items |
| BelowEBITDA | EBITDA − Net Income | D&A + interest + tax + one-offs, which the source doesn't split |
| SharesOutstanding | Net Income ÷ EPS | Blank when EPS = 0 |
| TotalDebtEst | D/E × Equity | **Estimate** |
| TotalAssetsEst | Net Income ÷ ROA | **Estimate**; blank when ROA ≈ 0 or result ≤ 0 |
| OtherLiabilitiesEst | Assets − Equity − Debt | **Estimate** |
| NetCashFlow | CFO + CFI + CFF | Ignores FX effects |
| FreeCashFlowEst | FCF/share × shares | **Estimate** |

## Known limitations (be upfront about these in interviews)

1. **Annual, not monthly.** The dataset is year-end only; the same model works for monthly data by swapping `DimYear` for a date table.
2. **No operating income line.** EBITDA is the operating-income proxy; the measure is named `Operating Income (EBITDA)` so nobody mistakes it for EBIT.
3. **No full balance sheet.** Current assets/liabilities aren't published, so multi-company current ratio is a simple average (exact for a single company-year).
4. **No department data.** Drill-through goes Category → Company → statement lines. A `DimDepartment` slots in without changing measures.
5. **Mixed industries.** Bank and insurer P&Ls don't have a meaningful COGS; filter by Category when comparing margins.
