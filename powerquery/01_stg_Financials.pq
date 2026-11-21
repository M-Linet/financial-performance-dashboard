// Query name: stg_Financials
// Staging query — right-click > uncheck "Enable load".
// Reads the raw CSV, fixes header quirks, types every column and
// rescales percentage columns. Every fact table references this query.
let
    Source = Csv.Document(
        File.Contents(DataFolder & RawFile),
        [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]
    ),
    Promoted = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),

    // The Kaggle header has "Company " with a trailing space — trim all names
    TrimmedNames = Table.TransformColumnNames(Promoted, Text.Trim),

    Renamed = Table.RenameColumns(
        TrimmedNames,
        {
            {"Market Cap(in B USD)", "MarketCapB"},
            {"Gross Profit", "GrossProfit"},
            {"Net Income", "NetIncome"},
            {"Earning Per Share", "EPS"},
            {"Share Holder Equity", "ShareholderEquity"},
            {"Cash Flow from Operating", "CFO"},
            {"Cash Flow from Investing", "CFI"},
            {"Cash Flow from Financial Activities", "CFF"},
            {"Current Ratio", "CurrentRatio"},
            {"Debt/Equity Ratio", "DebtToEquity"},
            {"Net Profit Margin", "NetProfitMargin"},
            {"Free Cash Flow per Share", "FCFPerShare"},
            {"Return on Tangible Equity", "ROTE"},
            {"Number of Employees", "Employees"},
            {"Inflation Rate(in US)", "InflationRate"}
        },
        MissingField.Ignore
    ),

    CleanText = Table.TransformColumns(
        Renamed,
        {
            {"Company", each Text.Upper(Text.Trim(_)), type text},
            {"Category", each Text.Trim(_), type text}
        }
    ),

    NumericCols = List.Difference(Table.ColumnNames(CleanText), {"Company", "Category"}),

    // Empty strings -> null before typing, so blanks don't become errors
    BlanksToNull = Table.ReplaceValue(CleanText, "", null, Replacer.ReplaceValue, NumericCols),

    Typed = Table.TransformColumnTypes(
        BlanksToNull,
        List.Transform(NumericCols, each {_, type number}),
        "en-US"
    ),
    ErrorsToNull = Table.ReplaceErrorValues(Typed, List.Transform(NumericCols, each {_, null})),
    YearAsInt = Table.TransformColumnTypes(ErrorsToNull, {{"Year", Int64.Type}, {"Employees", Int64.Type}}),

    // Percent columns -> decimals (25.3 -> 0.253)
    PctCols = List.Intersect({{"ROE", "ROA", "ROI", "NetProfitMargin", "ROTE", "InflationRate"}, Table.ColumnNames(YearAsInt)}),
    Scaled =
        if RatiosArePercent then
            Table.TransformColumns(YearAsInt, List.Transform(PctCols, each {_, (v) => if v = null then null else v / 100, type number}))
        else
            YearAsInt,

    // Guard against duplicate company-year rows
    NoBlankKeys = Table.SelectRows(Scaled, each [Company] <> null and [Company] <> "" and [Year] <> null),
    Deduped = Table.Distinct(NoBlankKeys, {"Company", "Year"})
in
    Deduped
