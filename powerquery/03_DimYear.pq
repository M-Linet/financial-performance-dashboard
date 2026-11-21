// Query name: DimYear
// Fiscal-year dimension covering every year in the data, plus the US
// inflation rate (one value per year in the source file).
let
    Years = List.RemoveNulls(List.Distinct(stg_Financials[Year])),
    MinYear = List.Min(Years),
    MaxYear = List.Max(Years),

    YearList = Table.FromList({MinYear..MaxYear}, Splitter.SplitByNothing(), {"Year"}),
    Typed = Table.TransformColumnTypes(YearList, {{"Year", Int64.Type}}),

    AddLabel = Table.AddColumn(Typed, "Fiscal Year", each "FY" & Text.From([Year]), type text),
    AddDate = Table.AddColumn(AddLabel, "Year End Date", each #date([Year], 12, 31), type date),
    AddLatest = Table.AddColumn(AddDate, "Is Latest Year", each [Year] = MaxYear, type logical),

    Inflation = Table.Group(stg_Financials, {"Year"}, {{"US Inflation Rate", each List.Average([InflationRate]), type nullable number}}),
    Joined = Table.NestedJoin(AddLatest, {"Year"}, Inflation, {"Year"}, "Infl", JoinKind.LeftOuter),
    Expanded = Table.ExpandTableColumn(Joined, "Infl", {"US Inflation Rate"}),
    Sorted = Table.Sort(Expanded, {{"Year", Order.Ascending}})
in
    Sorted
