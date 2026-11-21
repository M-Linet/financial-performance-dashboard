# Data dictionary

## Source

[Financial Statements dataset (Kaggle, rish1203)](https://www.kaggle.com/datasets/rish1203/financial-statements): annual figures compiled from 10-K reports for 12 large companies (AAPL, MSFT, GOOG, NVDA, INTC, AMZN, PYPL, AIG, BCS, MCD, PCG, SHLDQ), 2009–2023: 161 rows × 23 columns, one row per company-year. Coverage is uneven: PayPal starts in 2014, Sears ends in 2018, and FY2023 has only Microsoft and NVIDIA. Currency values are **USD millions**; market cap is **USD billions**; ROE/ROA/ROI/Net Profit Margin are **percentages**.

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
| Category | Category | DimCompany | Upper-cased (source mixes `Bank`/`BANK`). Use `Sector` for grouping |
| Market Cap(in B USD) | MarketCapB | FactBalanceSheet | USD bn; one value missing in source |
| Revenue | Revenue | FactIncomeStatement | |
| Gross Profit | GrossProfit | FactIncomeStatement | |
| Net Income | NetIncome | FactIncomeStatement | |
| Earning Per Share | EPS | FactIncomeStatement | |
| EBITDA | EBITDA | FactIncomeStatement | Used as **operating income**. Barclays' value is a placeholder `1`, so it's blanked |
| Share Holder Equity | ShareholderEquity | FactBalanceSheet | |
| Cash Flow from Operating / Investing / Financial Activities | CFO / CFI / CFF | FactCashFlow | |
| Current Ratio | CurrentRatio | FactBalanceSheet | Ratio only; blanked for banks/insurers (always `1.0` in source) |
| Debt/Equity Ratio | DebtToEquity | FactBalanceSheet | |
| ROE, ROA, ROI, Return on Tangible Equity | ROE, ROA, ROI, ROTE | FactBalanceSheet | ÷100 when `RatiosArePercent` |
| Net Profit Margin | NetProfitMargin | FactIncomeStatement | ÷100 |
| Free Cash Flow per Share | *dropped* | | Doesn't reconcile to filings (AAPL FY2022: 1.31 vs ~6.9) |
| Number of Employees | Employees | FactIncomeStatement | |
| Inflation Rate(in US) | US Inflation Rate | DimYear | ÷100 |

## Derived columns

| Column | Formula | Caveat |
|---|---|---|
| CostOfRevenue | Revenue − Gross Profit | ~0 for banks/insurers, where gross profit ≈ revenue |
| OperatingExpenses | Gross Profit − EBITDA | Includes R&D, SG&A, other operating items |
| BelowEBITDA | EBITDA − Net Income | D&A + interest + tax + one-offs, which the source doesn't split |
| SharesOutstanding | Net Income ÷ EPS | Blank when EPS = 0 |
| TotalDebt | D/E × Equity | Derived; ties to AAPL FY2022 10-K ($120.1B) |
| TotalAssets | Net Income ÷ ROA | Derived; ties to AAPL FY2022 10-K ($352.8B). Blank when ROA ≈ 0 or result ≤ 0 (5 rows) |
| OtherLiabilities | Assets − Equity − Debt | Derived |
| UnallocatedCosts | Gross Profit − Net Income | Only where EBITDA is missing (Barclays), so the waterfall still ties |
| NetCashFlow | CFO + CFI + CFF | Ignores FX effects |

## Data-quality rules applied in `stg_Financials`

Found by profiling the real file. Each rule is commented in the M code and mirrored in `scripts/reconcile.py`.

| Issue | Rows | Rule |
|---|---|---|
| `Company ` header has a trailing space | all | Trim column names |
| `Bank` vs `BANK` | 28 | Upper-case Category |
| Barclays EBITDA = 1 (placeholder) | 14 | Blank it |
| AIG / Barclays current ratio = 1.0 every year | 28 | Blank it for banks |
| Free Cash Flow per Share doesn't reconcile | all | Drop the column |
| PayPal FY2014 market cap missing | 1 | Left blank |

## Known limitations (be upfront about these in interviews)

1. **Annual, not monthly.** The dataset is year-end only; the same model works for monthly data by swapping `DimYear` for a date table.
2. **No operating income line.** EBITDA is the operating-income proxy; the measure is named `Operating Income (EBITDA)` so nobody mistakes it for EBIT.
3. **No full balance sheet.** Debt and assets are derived from ratios (exact where the ratios are exact). Current assets/liabilities aren't published, so multi-company current ratio is a simple average (exact for a single company-year).
4. **No department data.** Drill-through goes Sector → Company → statement lines. A `DimDepartment` slots in without changing measures.
5. **Mixed industries.** Bank and insurer P&Ls don't have a meaningful COGS; filter by Sector when comparing margins.
6. **Negative equity.** McDonald's (2016–2022) and Sears (2015–2018) have negative shareholder equity, so their ROE and D/E come out negative and aren't comparable with the rest. Read them as a solvency flag.
7. **Partial final year.** FY2023 has 2 of 12 companies. `DimYear[Is Latest Full Year]` marks FY2022; default the slicers there, and use like-for-like growth across years where the company set changes.
