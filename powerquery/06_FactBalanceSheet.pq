// Query name: FactBalanceSheet
// Point-in-time balance-sheet view per company-year (year-end).
// The dataset publishes equity and ratios, not full balance sheets, so
// three lines are DERIVED by reversing the published ratios:
//   Total Debt        = Debt/Equity x Shareholder Equity
//   Total Assets      = Net Income / ROA
//   Other Liabilities = Total Assets - Equity - Debt
// Check: AAPL FY2022 gives Total Assets $352,755M and Total Debt $120,067M,
// matching Apple's 10-K. Assets are left blank when ROA is ~0 (Net Income
// near zero makes the division unstable) or the result is not positive.
let
    Source = Table.SelectColumns(
        stg_Financials,
        {"Company", "Year", "ShareholderEquity", "DebtToEquity", "CurrentRatio", "NetIncome",
         "ROA", "ROE", "ROI", "ROTE", "MarketCapB"}
    ),
    AddDebt = Table.AddColumn(Source, "TotalDebt",
        each if [DebtToEquity] = null or [ShareholderEquity] = null then null else [DebtToEquity] * [ShareholderEquity],
        type nullable number),
    AddAssets = Table.AddColumn(AddDebt, "TotalAssets",
        each if [ROA] = null or Number.Abs([ROA]) < 0.0005 or [NetIncome] = null then null
             else [NetIncome] / [ROA],
        type nullable number),
    CleanAssets = Table.TransformColumns(AddAssets, {{"TotalAssets", each if _ = null or _ <= 0 then null else _, type nullable number}}),
    AddOtherLiab = Table.AddColumn(CleanAssets, "OtherLiabilities",
        each if [TotalAssets] = null or [ShareholderEquity] = null or [TotalDebt] = null then null
             else [TotalAssets] - [ShareholderEquity] - [TotalDebt],
        type nullable number),
    Final = Table.RemoveColumns(AddOtherLiab, {"NetIncome"})
in
    Final
