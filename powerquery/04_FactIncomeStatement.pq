// Query name: FactIncomeStatement
// One row per company-year. Derives the P&L bridge lines the dataset
// doesn't publish directly:
//   Cost of Revenue    = Revenue - Gross Profit
//   Operating Expenses = Gross Profit - EBITDA
//   Below EBITDA       = EBITDA - Net Income   (D&A, interest, tax, other)
//   Unallocated Costs  = Gross Profit - Net Income, ONLY when EBITDA is
//                        missing (Barclays), so the bridge still ties out
// Operating income is not in the source file; EBITDA is used as the
// operating-income measure throughout (see docs/data-dictionary.md).
let
    Source = Table.SelectColumns(
        stg_Financials,
        {"Company", "Year", "Revenue", "GrossProfit", "EBITDA", "NetIncome", "EPS", "Employees", "NetProfitMargin"}
    ),
    AddCOGS = Table.AddColumn(Source, "CostOfRevenue",
        each if [Revenue] = null or [GrossProfit] = null then null else [Revenue] - [GrossProfit], type nullable number),
    AddOpex = Table.AddColumn(AddCOGS, "OperatingExpenses",
        each if [GrossProfit] = null or [EBITDA] = null then null else [GrossProfit] - [EBITDA], type nullable number),
    AddBelow = Table.AddColumn(AddOpex, "BelowEBITDA",
        each if [EBITDA] = null or [NetIncome] = null then null else [EBITDA] - [NetIncome], type nullable number),
    AddUnallocated = Table.AddColumn(AddBelow, "UnallocatedCosts",
        each if [EBITDA] = null and [GrossProfit] <> null and [NetIncome] <> null then [GrossProfit] - [NetIncome] else null,
        type nullable number),
    // Shares outstanding (millions) implied by Net Income / EPS
    AddShares = Table.AddColumn(AddUnallocated, "SharesOutstanding",
        each if [EPS] = null or [EPS] = 0 or [NetIncome] = null then null else [NetIncome] / [EPS], type nullable number),
    Reordered = Table.ReorderColumns(AddShares,
        {"Company", "Year", "Revenue", "CostOfRevenue", "GrossProfit", "OperatingExpenses", "EBITDA",
         "BelowEBITDA", "UnallocatedCosts", "NetIncome", "EPS", "SharesOutstanding", "Employees", "NetProfitMargin"})
in
    Reordered
