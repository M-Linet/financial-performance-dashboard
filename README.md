# Financial Performance Dashboard (Power BI)

**Replacing a manual Excel month-end reporting pack with a refreshable, three-page Power BI dashboard.**

![Power BI](https://img.shields.io/badge/Power%20BI-Desktop-F2C811?logo=powerbi&logoColor=black)
![Power Query](https://img.shields.io/badge/Power%20Query-M-217346)
![DAX](https://img.shields.io/badge/DAX-45%2B%20measures-1F4E79)
![Level](https://img.shields.io/badge/Difficulty-Advanced-C2413A)

---

## The problem

Finance teams still build monthly leadership reports in Excel: refresh pivot tables by hand, copy numbers between tabs, export a static PDF, repeat next month. It is slow and error-prone, and it can't answer the follow-up question *"why did margin drop?"* without another round of spreadsheet work.

## The solution

A Power BI model that takes the raw financial statements file, shapes it automatically in Power Query, calculates every KPI with DAX, and serves it as an interactive report. Next period: drop in the new file → **Refresh**.

| Manual Excel process | This dashboard |
|---|---|
| Copy/paste raw exports into tabs | Power Query reads the source files directly |
| Re-point pivot ranges every month | Star schema; refresh picks up new rows |
| Ratios in fragile cell formulas | 45+ documented, reusable DAX measures |
| Static PDF to leadership | Interactive report + scheduled refresh + email subscription |
| "Can you break that down by company?" = another day | Drill-through to company statements in one click |

---

## Dashboard pages

| # | Page | What it shows |
|---|---|---|
| 1 | **P&L Overview** | KPI cards (Revenue, Gross Margin, Operating Income, Net Income, like-for-like growth) and a **waterfall** bridging Revenue → Net Income |
| 2 | **Trends** | **Combo chart** of revenue & operating income (columns) vs net margin (line); simple vs like-for-like YoY growth; cash flow by activity; gross-margin small multiples by sector (FY2023 excluded as a partial year) |
| 3 | **Balance Sheet & Ratios** | Matrix by Sector → Company with equity, debt, assets, **current ratio** (RAG-colored), D/E, ROE; leverage-vs-return scatter; funding-structure bars |
| ↳ | **Company Detail** *(drill-through)* | Right-click any company → full statement view (line items × years) plus current ratio and D/E trend |

| P&L Overview | Trends |
|---|---|
| ![P&L Overview](docs/screenshots/01-pl-overview.png) | ![Trends](docs/screenshots/02-trends.png) |
| **Balance Sheet & Ratios** | **Company Detail (drill-through)** |
| ![Balance Sheet](docs/screenshots/03-balance-sheet.png) | ![Company Detail](docs/screenshots/04-company-detail.png) |

---

## Data model

```mermaid
erDiagram
    DimCompany ||--o{ FactIncomeStatement : Company
    DimCompany ||--o{ FactPLWaterfall : Company
    DimCompany ||--o{ FactBalanceSheet : Company
    DimCompany ||--o{ FactCashFlow : Company
    DimYear ||--o{ FactIncomeStatement : Year
    DimYear ||--o{ FactPLWaterfall : Year
    DimYear ||--o{ FactBalanceSheet : Year
    DimYear ||--o{ FactCashFlow : Year

    DimCompany {
        text Company PK
        text CompanyName
        text Sector
        text Sector
        text Country
    }
    DimYear {
        int Year PK
        text FiscalYear
        date YearEndDate
        bool IsLatestYear
        number USInflationRate
    }
    FactIncomeStatement {
        text Company
        int Year
        number Revenue
        number CostOfRevenue
        number GrossProfit
        number OperatingExpenses
        number EBITDA
        number NetIncome
    }
    FactPLWaterfall {
        text Company
        int Year
        int StepOrder
        text LineItem
        number Amount
    }
    FactBalanceSheet {
        text Company
        int Year
        number ShareholderEquity
        number TotalDebt
        number TotalAssets
        number CurrentRatio
        number DebtToEquity
    }
    FactCashFlow {
        text Company
        int Year
        number CFO
        number CFI
        number CFF
        number NetCashFlow
    }
```

**Power Query pipeline:** three source files (raw statements CSV + `company_master.csv` + `pl_waterfall_steps.csv`) → one staging query (header fixes, typing, % rescaling, de-dup, and the data-quality rules below) → two dimensions and four fact tables. All file paths come from parameters, so moving the project or swapping in a new period is a one-field change.

---

## Key DAX measures

Full list with comments: [`dax/measures.dax`](dax/measures.dax)

| Measure | Logic |
|---|---|
| Gross Margin % | `DIVIDE([Gross Profit], [Revenue])` |
| Operating Income (EBITDA) | `SUM(FactIncomeStatement[EBITDA])`, the dataset's operating-income line |
| Revenue YoY % | Current year vs `CALCULATE([Revenue], REMOVEFILTERS(DimYear), DimYear[Year] = _Year - 1)` |
| Revenue YoY % (LFL) | Same, but only for companies reporting in **both** years (`SUMX` over comparable companies). Removes growth that is really just a company joining the dataset |
| Revenue CAGR % | `(Last / First) ^ (1 / years) - 1` over the years in context |
| Current Ratio | `LASTNONBLANKVALUE(DimYear[Year], AVERAGE(...))`, semi-additive, so it never sums across years |
| Debt to Equity | Weighted: total debt ÷ total equity (not an average of ratios) |
| Shareholder Equity / Total Assets | `LASTNONBLANKVALUE`: closing balance, correct in any total row |
| Waterfall Amount | `SUM(FactPLWaterfall[Amount])`, with signed steps from the reference file |

```dax
Revenue YoY % (LFL) =
VAR _Comparable =
    FILTER ( VALUES ( DimCompany[Company] ),
             NOT ISBLANK ( [Revenue] ) && NOT ISBLANK ( [Revenue PY] ) )
VAR _Cur  = SUMX ( _Comparable, [Revenue] )
VAR _Prev = SUMX ( _Comparable, [Revenue PY] )
RETURN DIVIDE ( _Cur - _Prev, _Prev )
```

---

## Key insights (FY2009–FY2022, 12 companies, USD)

1. **Amazon grew fastest but earned the least.** Revenue compounded at **26% a year**, from $24.5B to $514B, and was 31% of the group's FY2022 revenue. Yet FY2022 ended in a **$2.7B net loss** (−0.5% margin). The waterfall shows where: EBITDA was still **+$54B**, and the loss comes entirely from the D&A, interest & tax step (−$56.9B).
2. **Intel had the sharpest reversal.** In FY2022 revenue fell **20%**, net income fell **60%**, and gross margin dropped from 55.4% to **42.6%** (−12.8 pp), its lowest in the dataset.
3. **Microsoft and NVIDIA lead on profitability.** Both posted net margins of about **36–37%** in FY2022. Microsoft's net margin rose from 24.9% in FY2009.
4. **McDonald's is very profitable on negative equity.** It earned a 26.6% net margin in FY2022 with **negative shareholder equity every year since FY2016** (−$6.0B in FY2022), so its ROE and D/E are not comparable to peers. The model flags rather than averages them.
5. **PG&E and Sears show distress in the numbers.** PG&E lost **$6.9B and $7.7B** in FY2018–19 before returning to a $1.8B profit in FY2022, and had the lowest FY2022 current ratio (0.81x). Sears' revenue shrank about **11% a year** with seven straight loss years (FY2012–18) before it drops out of the data.
6. **The comparable set matters.** Simple FY2023 revenue growth reads **−85%** because only two companies have reported. Like-for-like growth is **+6%**. That's why the dashboard defaults to FY2022 and shows both growth measures.

## Data-quality issues handled

Profiling the real file turned up issues a manual Excel process would silently carry into the board pack:

| Issue | Fix |
|---|---|
| `Bank` vs `BANK`; PG&E labelled *Manufacturing*, Sears *Finance* | Upper-case categories; group by a curated `Sector` from `company_master.csv` |
| Barclays EBITDA is a placeholder `1` in every year | Blanked; the waterfall uses an *unallocated costs* step so it still ties to net income |
| Banks report current ratio = 1.0 every year | Blanked for banks/insurers |
| "Free Cash Flow per Share" doesn't reconcile to filings | Dropped |
| FY2023 has 2 of 12 companies | `Is Latest Full Year` flag; like-for-like growth measure |

`scripts/reconcile.py` re-checks all of this and confirms the P&L bridge ties to net income for every company-year.

## Repo structure

```
├── data/
│   ├── raw/                  # Kaggle CSV goes here (git-ignored)
│   ├── sample/               # synthetic sample, same schema, so the repo runs out of the box
│   └── reference/            # company master + P&L bridge definition
├── powerquery/               # 00–07 M queries, paste in order
├── dax/measures.dax          # all measures, loadable via DAX query view
├── theme/finance-theme.json  # report theme
├── scripts/
│   ├── make_sample_data.py   # regenerates the synthetic sample
│   └── reconcile.py          # independent pandas re-calc to tie out dashboard numbers
├── report/                   # .pbip / .pbix lives here
└── docs/
    ├── build-guide.md        # step-by-step build instructions
    ├── data-dictionary.md    # columns, derivations, limitations
    └── screenshots/
```

## How to run it

1. Clone the repo and download the dataset into `data/raw/` ([instructions](data/README.md)), or skip this and use the bundled sample.
2. Follow [`docs/build-guide.md`](docs/build-guide.md): parameters → paste M queries → relationships → load DAX → build pages.
3. Tie out the numbers:
   ```bash
   pip install pandas numpy
   python scripts/reconcile.py "data/raw/Financial Statements.csv"
   ```
   The output matches the `EVALUATE` query at the bottom of `measures.dax`. It also checks that the P&L bridge sums to net income.

## Assumptions and limitations

The dataset is **annual, company-level** and publishes ratios rather than full balance sheets. So:
- **EBITDA** is used as operating income (named that way so it isn't confused with EBIT).
- **Total debt and total assets are derived** by reversing the published D/E and ROA. This reproduces Apple's FY2022 10-K exactly (assets $352.8B, debt $120.1B).
- Drill-through goes **Sector → Company → statement lines**. The model is ready for a `DimDepartment` if department-level data is available.

Details: [`docs/data-dictionary.md`](docs/data-dictionary.md).

## Skills demonstrated

Power Query (parameterized multi-file ingestion, unpivoting, reference-table joins, error handling) · star-schema modeling · DAX time intelligence without a date table · semi-additive measures · like-for-like growth · waterfall / combo / matrix / small-multiples visuals · drill-through · conditional formatting by measure · themes · data reconciliation.

---

*Dataset: [Financial Statements, Kaggle (rish1203)](https://www.kaggle.com/datasets/rish1203/financial-statements). Sample data in `data/sample/` is synthetic and does not represent any real company.*
