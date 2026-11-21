// Query name: FactCashFlow
// Cash flow by activity per company-year.
// (The source's "Free Cash Flow per Share" column doesn't reconcile to
//  filings, so it is dropped in stg_Financials; no FCF is derived.)
let
    Source = Table.SelectColumns(stg_Financials, {"Company", "Year", "CFO", "CFI", "CFF"}),
    AddNet = Table.AddColumn(Source, "NetCashFlow",
        each List.Sum(List.RemoveNulls({[CFO], [CFI], [CFF]})), type nullable number)
in
    AddNet
