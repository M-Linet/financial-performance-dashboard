// Query name: DimCompany
// One row per company. Joins the dataset's tickers to the reference
// company_master.csv (second source file). Unknown tickers fall back to
// the ticker itself, so new companies in the CSV never break refresh.
let
    Companies = Table.Distinct(Table.SelectColumns(stg_Financials, {"Company", "Category"}), {"Company"}),

    MasterRaw = Csv.Document(
        File.Contents(DataFolder & "reference\company_master.csv"),
        [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]
    ),
    Master = Table.PromoteHeaders(MasterRaw, [PromoteAllScalars = true]),
    MasterClean = Table.TransformColumns(Master, {{"Ticker", each Text.Upper(Text.Trim(_)), type text}}),

    Joined = Table.NestedJoin(Companies, {"Company"}, MasterClean, {"Ticker"}, "Master", JoinKind.LeftOuter),
    Expanded = Table.ExpandTableColumn(Joined, "Master", {"CompanyName", "Sector", "Country"}),

    WithName = Table.AddColumn(Expanded, "Company Name",
        each if [CompanyName] = null or [CompanyName] = "" then [Company] else [CompanyName], type text),
    WithSector = Table.AddColumn(WithName, "Sector Name",
        each if [Sector] = null or [Sector] = "" then [Category] else [Sector], type text),
    WithCountry = Table.AddColumn(WithSector, "Country Name",
        each if [Country] = null or [Country] = "" then "Unknown" else [Country], type text),

    Final = Table.SelectColumns(WithCountry, {"Company", "Company Name", "Category", "Sector Name", "Country Name"}),
    Renamed = Table.RenameColumns(Final, {{"Sector Name", "Sector"}, {"Country Name", "Country"}}),
    Sorted = Table.Sort(Renamed, {{"Company Name", Order.Ascending}})
in
    Sorted
