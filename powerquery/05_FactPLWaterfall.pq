// Query name: FactPLWaterfall
// Long-format P&L bridge for the waterfall visual. Step names, order and
// signs come from reference\pl_waterfall_steps.csv (third source file),
// so finance can rename or reorder steps without touching M code.
// The waterfall's automatic Total bar = Net Income.
let
    StepsRaw = Csv.Document(
        File.Contents(DataFolder & "reference\pl_waterfall_steps.csv"),
        [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]
    ),
    Steps = Table.TransformColumnTypes(
        Table.PromoteHeaders(StepsRaw, [PromoteAllScalars = true]),
        {{"StepOrder", Int64.Type}, {"LineItem", type text}, {"SourceColumn", type text}, {"Sign", type number}},
        "en-US"
    ),
    StepColumns = Steps[SourceColumn],

    Income = Table.SelectColumns(FactIncomeStatement, {"Company", "Year"} & StepColumns),
    Unpivoted = Table.UnpivotOtherColumns(Income, {"Company", "Year"}, "SourceColumn", "Value"),

    Joined = Table.NestedJoin(Unpivoted, {"SourceColumn"}, Steps, {"SourceColumn"}, "Step", JoinKind.Inner),
    Expanded = Table.ExpandTableColumn(Joined, "Step", {"StepOrder", "LineItem", "Sign"}),
    AddAmount = Table.AddColumn(Expanded, "Amount", each [Value] * [Sign], type number),

    Final = Table.SelectColumns(AddAmount, {"Company", "Year", "StepOrder", "LineItem", "Amount"}),
    Sorted = Table.Sort(Final, {{"Company", Order.Ascending}, {"Year", Order.Ascending}, {"StepOrder", Order.Ascending}})
in
    Sorted
