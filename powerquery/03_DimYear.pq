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

    PerYear = Table.Group(
        stg_Financials,
        {"Year"},
        {
            {"US Inflation Rate", each List.Average([InflationRate]), type nullable number},
            {"Companies Reporting", each Table.RowCount(_), Int64.Type}
        }
    ),
    Joined = Table.NestedJoin(AddLatest, {"Year"}, PerYear, {"Year"}, "PY", JoinKind.LeftOuter),
    Expanded = Table.ExpandTableColumn(Joined, "PY", {"US Inflation Rate", "Companies Reporting"}),

    // In the real file FY2023 has only 2 of 12 companies. "Latest full year" =
    // the latest year where at least 80% of the peak number of companies report.
    // Use it as the default selection for the year slicers.
    MaxCount = List.Max(Expanded[Companies Reporting]),
    FullYears = Table.SelectRows(Expanded, each [Companies Reporting] <> null and [Companies Reporting] >= 0.8 * MaxCount)[Year],
    LatestFullYear = List.Max(FullYears),
    AddFull = Table.AddColumn(Expanded, "Is Latest Full Year", each [Year] = LatestFullYear, type logical),
    Sorted = Table.Sort(AddFull, {{"Year", Order.Ascending}})
in
    Sorted
