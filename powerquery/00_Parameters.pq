// ============================================================
// PARAMETERS — create each one via Home > Manage Parameters > New,
// or paste each block into a Blank Query (Advanced Editor) and
// rename the query to the name shown.
// ============================================================

// Query name: DataFolder
// Absolute path to the repo's /data folder. Keep the trailing backslash.
"C:\Projects\financial-performance-dashboard\data\" meta [IsParameterQuery = true, Type = "Text", IsParameterQueryRequired = true]


// Query name: RawFile
// Path of the financial statements CSV, relative to DataFolder.
//   Real Kaggle file :  raw\Financial Statements.csv
//   Synthetic sample :  sample\financial_statements_sample.csv
"sample\financial_statements_sample.csv" meta [IsParameterQuery = true, Type = "Text", IsParameterQueryRequired = true]


// Query name: RatiosArePercent
// The Kaggle file stores ROE, ROA, ROI, Net Profit Margin etc. as
// percentages (e.g. 25.3 = 25.3%). TRUE divides them by 100.
true meta [IsParameterQuery = true, Type = "Logical", IsParameterQueryRequired = true]
