// Query name: FactCashFlow
// Cash flow by activity per company-year, plus an estimated free cash
// flow (FCF per share x implied shares outstanding).
let
    Source = Table.SelectColumns(stg_Financials, {"Company", "Year", "CFO", "CFI", "CFF", "FCFPerShare"}),
    AddNet = Table.AddColumn(Source, "NetCashFlow",
        each List.Sum(List.RemoveNulls({[CFO], [CFI], [CFF]})), type nullable number),

    Shares = Table.SelectColumns(FactIncomeStatement, {"Company", "Year", "SharesOutstanding"}),
    Joined = Table.NestedJoin(AddNet, {"Company", "Year"}, Shares, {"Company", "Year"}, "S", JoinKind.LeftOuter),
    Expanded = Table.ExpandTableColumn(Joined, "S", {"SharesOutstanding"}),
    AddFCF = Table.AddColumn(Expanded, "FreeCashFlowEst",
        each if [FCFPerShare] = null or [SharesOutstanding] = null then null else [FCFPerShare] * [SharesOutstanding],
        type nullable number),
    Final = Table.RemoveColumns(AddFCF, {"SharesOutstanding"})
in
    Final
