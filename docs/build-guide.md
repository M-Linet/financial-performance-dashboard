# Build guide — step by step in Power BI Desktop

Time: roughly 3–4 hours the first time. Every M query and DAX measure is already written; this guide is about wiring them up and building the visuals.

---

## 0. Prerequisites

- Power BI Desktop (current monthly release, with DAX query view and TMDL view, which are GA in recent builds)
- This repo cloned locally, e.g. `C:\Projects\financial-performance-dashboard`
- The Kaggle CSV saved as `data\raw\Financial Statements.csv`, **or** use the synthetic sample that ships in `data\sample\`

Optional: Python 3.10+ with pandas for `scripts/reconcile.py`.

---

## 1. Power Query: parameters and sources

1. **Home → Transform data** opens Power Query Editor.
2. **Home → Manage Parameters → New** and create three parameters (values in `powerquery/00_Parameters.pq`):

   | Name | Type | Example value |
   |---|---|---|
   | `DataFolder` | Text | `C:\Projects\financial-performance-dashboard\data\` |
   | `RawFile` | Text | `raw\Financial Statements.csv` (or `sample\financial_statements_sample.csv`) |
   | `RatiosArePercent` | True/False | `TRUE` |

3. For each file `01`–`07` in `powerquery/`: **Home → New Source → Blank Query → Advanced Editor**, paste the code, then rename the query to the name in the file's first comment line.

   | Query | Load? | Purpose |
   |---|---|---|
   | `stg_Financials` | ❌ uncheck *Enable load* | Clean, typed staging copy of the raw CSV |
   | `DimCompany` | ✅ | Companies + reference `company_master.csv` |
   | `DimYear` | ✅ | Fiscal years + US inflation |
   | `FactIncomeStatement` | ✅ | P&L lines incl. derived COGS / OpEx |
   | `FactPLWaterfall` | ✅ | Long P&L bridge driven by `pl_waterfall_steps.csv` |
   | `FactBalanceSheet` | ✅ | Equity, est. debt/assets, liquidity ratios |
   | `FactCashFlow` | ✅ | CFO / CFI / CFF, est. free cash flow |

4. Put the queries in groups (right-click → *Move to group*): **Parameters**, **Staging**, **Dimensions**, **Facts**. It keeps the editor tidy.
5. **Close & Apply**.

> **Why this replaces the Excel process:** the whole shaping chain is recorded once. Next month you drop a new CSV in `data\raw\` (or point `RawFile` at it) and press **Refresh**. No re-pasting, no fixing broken pivot ranges.

---

## 2. Model view: relationships

Create these relationships, all **one-to-many, single direction** (Dim filters Fact):

| From (1) | To (*) |
|---|---|
| `DimCompany[Company]` | `FactIncomeStatement[Company]`, `FactPLWaterfall[Company]`, `FactBalanceSheet[Company]`, `FactCashFlow[Company]` |
| `DimYear[Year]` | `FactIncomeStatement[Year]`, `FactPLWaterfall[Year]`, `FactBalanceSheet[Year]`, `FactCashFlow[Year]` |

Then:

- Hide every `Company` and `Year` column **on the fact tables** (right-click → *Hide in report view*), so report builders always slice through the dimensions. The time-intelligence measures rely on this.
- `FactPLWaterfall[LineItem]` → **Column tools → Sort by column → `StepOrder`**. Hide `StepOrder`.
- `DimYear[Fiscal Year]` → Sort by column → `Year`.
- `DimYear[Year]` → Summarization: *Don't summarize*.
- Hierarchy on `DimCompany`: **Category → Company Name** (right-click Category → *Create hierarchy*). This is the drill path.

The result is a star schema with two shared dimensions and four facts at company-year grain.

---

## 3. DAX measures

1. **Home → Enter data** → name the table `_Measures`, leave the single column, **Load**.
2. Open **DAX query view**, paste all of `dax/measures.dax`.
3. Click the CodeLens **"Update model: Add new measures"** above `DEFINE`.
4. Press **Run**. The `EVALUATE` returns a year-by-year table. Compare it with `scripts/output/expected_by_year.csv` from `python scripts/reconcile.py` (same CSV), since both should match.
5. Delete the dummy column in `_Measures`; Power BI then shows it at the top as a measure table.
6. Set formats (Measure tools → Format), following the `// fmt:` comments:

   | Measures | Format |
   |---|---|
   | Currency (Revenue, Gross Profit, Net Income, Equity, Debt, cash flows…) | Source values are already **USD millions**. Use custom `$#,0"M"`, or `$#,0,.0"B"` to show billions (one comma = ÷1,000). Set visual display units to **None** so Power BI doesn't rescale again. |
   | `%` measures, YoY, CAGR | Percentage, 1 decimal |
   | `Current Ratio`, `Debt to Equity`, `Cash Conversion` | Custom `0.00"x"` |
   | `Gross Margin Δ (pp)` | Custom `+0.0" pp";-0.0" pp"` |
   | `Market Cap ($B)` | Custom `$#,0.0"B"` |

7. Optional display folders (Properties pane): `1 P&L`, `2 Margins`, `3 Time intelligence`, `4 Balance sheet`, `5 Ratios`, `6 Cash flow`, `7 Helpers`.

---

## 4. Theme

**View → Themes → Browse for themes** → `theme/finance-theme.json`. It sets the palette, a light-grey canvas, white cards and the waterfall colors (green increase, red decrease, navy total).

Canvas: 1280 × 720 (16:9) on every page.

---

## 5. Page 1: P&L Overview

**Slicers (top band):** `DimYear[Fiscal Year]` (dropdown, **single select**), `DimCompany[Category]`, `DimCompany[Company Name]` (dropdown, multi-select).

**KPI row: 5 cards** (new card visual; use *reference labels* for the comparison line):

| Card | Value | Reference label |
|---|---|---|
| Revenue | `[Revenue]` | `[Revenue YoY %]`, font color = field value `[CF YoY Colour]` |
| Gross Margin | `[Gross Margin %]` | `[Gross Margin Δ (pp)]` |
| Operating Income (EBITDA) | `[Operating Income (EBITDA)]` | `[Operating Margin %]` |
| Net Income | `[Net Income]` | `[Net Margin %]` |
| Like-for-like growth | `[Revenue YoY % (LFL)]` | `[Revenue YoY Δ]` |

**Waterfall chart (main visual, ~60% width):**
- Category: `FactPLWaterfall[LineItem]`
- Y-axis: `[Waterfall Amount]`
- Format → Sentiment colors from the theme; **Total label → rename to “Net Income”** (Format → X-axis / Total label, depending on build)
- Title: *fx* → field value `[Title P&L Bridge]`
- Data labels on, display units: None (values are already $M)

Reading it: Revenue (green) → minus Cost of Revenue → minus Operating Expenses → minus D&A, interest & tax → **Net Income** total bar.

**Supporting visual (right side):** clustered bar *Net Margin % by Company Name*, sorted descending. Clicking a bar cross-filters the waterfall.

---

## 6. Page 2: Trends

No year slicer on this page (trends need all years). Keep the Category / Company slicers and **sync** them with Page 1 (View → Sync slicers).

1. **Line and clustered column chart** (the combo chart)
   - X-axis: `DimYear[Year]` (type: categorical)
   - Column y-axis: `[Revenue]`, `[Operating Income (EBITDA)]`
   - Line y-axis: `[Net Margin %]` (secondary axis on)
   - Title: “Revenue & operating income vs net margin”
2. **Line chart:** `[Revenue YoY %]` and `[Revenue YoY % (LFL)]` by Year. Add a constant line at 0. The gap between the two lines shows how much "growth" comes from companies entering or leaving the set.
3. **Clustered column:** `[Operating Cash Flow]`, `[Investing Cash Flow]`, `[Financing Cash Flow]` by Year, with `[Net Cash Flow]` as a line (another combo).
4. **Small multiples line chart:** `[Gross Margin %]` by Year, small multiples = `DimCompany[Company Name]`, 4 columns. This is the view leadership usually asks for after the first meeting.
5. Optional: card with `[Revenue CAGR %]`.

---

## 7. Page 3: Balance Sheet & Ratios

**Slicer:** `DimYear[Fiscal Year]` single select (sync with Page 1).

**Matrix (main visual):**
- Rows: the `DimCompany` hierarchy **Category → Company Name** (turn on +/- icons, start collapsed at Category)
- Values: `[Shareholder Equity]`, `[Total Debt (est.)]`, `[Total Assets (est.)]`, `[Current Ratio]`, `[Debt to Equity]`, `[ROE %]`, `[Market Cap ($B)]`
- Conditional formatting:
  - `Current Ratio` → Background color → *Field value* → `[CF Current Ratio Colour]` (red < 1.0x, amber < 1.5x, green ≥ 1.5x)
  - `Debt to Equity` → Data bars
  - `ROE %` → Icons (up/down arrows by sign)
- Title: *fx* → `[Title Balance Sheet]`

**Supporting visuals:**
- Scatter chart: X = `[Debt to Equity]`, Y = `[ROE %]`, Values/Details = `Company Name`, Size = `[Market Cap ($B)]`. A quick leverage-vs-return view.
- Stacked bar: `[Shareholder Equity]`, `[Total Debt (est.)]`, `[Other Liabilities (est.)]` by Company Name. This is the funding structure, and it adds up to estimated total assets.
- Text box footnote: *“Debt and total assets are estimated from published D/E and ROA ratios.”*

---

## 8. Drill-through page: Company Detail

1. Add a page named **Company Detail**. In the Visualizations pane → *Drill through* → add `DimCompany[Company Name]` (and keep *Cross-report* off, *Keep all filters* **on** so the selected year carries over).
2. Power BI adds a **Back** button automatically.
3. Build:
   - Header card: `[Selection Label]`
   - **Matrix "statement view"**: Columns = `DimYear[Year]`; Values = `[Revenue]`, `[Cost of Revenue]`, `[Gross Profit]`, `[Operating Expenses]`, `[Operating Income (EBITDA)]`, `[D&A, Interest & Tax]`, `[Net Income]`, `[Shareholder Equity]`, `[Total Debt (est.)]`, `[Total Assets (est.)]`, `[Operating Cash Flow]`, `[Free Cash Flow (est.)]`. Turn on **Format → Values → Options → Switch values to rows**. That gives a classic financial statement layout, line items down and years across.
   - Mini waterfall (same fields as Page 1) for the company
   - Line: `[Current Ratio]` and `[Debt to Equity]` by Year
4. **Hide the page** (right-click tab → Hide). Users only reach it by right-clicking a company in the Page 3 matrix (or any visual) → **Drill through → Company Detail**.
5. Add a small text hint on Page 3: *“Right-click a company → Drill through for its full statements.”*

> The Kaggle dataset is at company level, so the drill path is **Category → Company → statement line items × year**. If your real data has departments or cost centers, add a `DimDepartment` table and put it on the drill-through page the same way; the measures don't change.

---

## 9. Finishing touches

- Page navigator (Insert → Buttons → Navigator → Page navigator) on each page header.
- Tooltips: add `[Revenue YoY %]` and `[Net Margin %]` to the tooltip well of the main visuals.
- Turn off *Auto date/time* (File → Options → Current file → Data load). The model uses integer fiscal years, so the hidden date tables are dead weight.
- **Performance analyzer** run: every visual should render < 300 ms on this data size.

---

## 10. Save, refresh and publish

- **Save as PBIP** (File → Save as → *Power BI project (.pbip)*) into `report/`. PBIP stores the model (TMDL) and report as text, so GitHub shows real diffs. Or save `report/Financial Performance Dashboard.pbix` if you prefer a single file.
- Take screenshots of each page into `docs/screenshots/` (`01-pl-overview.png`, `02-trends.png`, `03-balance-sheet.png`, `04-company-detail.png`); the README already links to those names.
- **Publish** to the Power BI Service. For automatic refresh of a local folder source you need an on-premises data gateway (personal mode is fine). Alternatively, move the CSVs to SharePoint/OneDrive and switch `File.Contents` to `SharePoint.Files`, which needs no gateway. Then set **Scheduled refresh** (e.g. daily 06:00).
- Replace the "static PDF to leadership" step with an **email subscription** on the report in the Service.
