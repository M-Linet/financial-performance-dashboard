// Query name: FactBalanceSheet
// Point-in-time balance-sheet view per company-year (year-end).
// The dataset publishes equity and ratios, not full balance sheets, so
// two lines are ESTIMATED from the published ratios:
//   Total Debt (est.)   = Debt/Equity x Shareholder Equity
//   Total Assets (est.) = Net Income / ROA
//   Other Liabilities   = Total Assets - Equity - Debt
// Assets are left blank when ROA is ~0 (division would explode).
let
    Source = Table.SelectColumns(
        stg_Financials,
        {"Company", "Year", "ShareholderEquity", "DebtToEquity", "CurrentRatio", "NetIncome",
         "ROA", "ROE", "ROI", "ROTE", "MarketCapB"}
    ),
    AddDebt = Table.AddColumn(Source, "TotalDebtEst",
        each if [DebtToEquity] = null or [ShareholderEquity] = null then null else [DebtToEquity] * [ShareholderEquity],
        type nullable number),
    AddAssets = Table.AddColumn(AddDebt, "TotalAssetsEst",
        each if [ROA] = null or Number.Abs([ROA]) < 0.0005 or [NetIncome] = null then null
             else [NetIncome] / [ROA],
        type nullable number),
    // A negative asset estimate (loss year with positive ROA, or vice versa) is meaningless
    CleanAssets = Table.TransformColumns(AddAssets, {{"TotalAssetsEst", each if _ = null or _ <= 0 then null else _, type nullable number}}),
    AddOtherLiab = Table.AddColumn(CleanAssets, "OtherLiabilitiesEst",
        each if [TotalAssetsEst] = null or [ShareholderEquity] = null or [TotalDebtEst] = null then null
             else [TotalAssetsEst] - [ShareholderEquity] - [TotalDebtEst],
        type nullable number),
    Final = Table.RemoveColumns(AddOtherLiab, {"NetIncome"})
in
    Final
