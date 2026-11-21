# Data

| Folder | Contents | In git? |
|---|---|---|
| `raw/` | Put the Kaggle file here as `Financial Statements.csv` | ❌ ignored, so download it yourself |
| `sample/` | `financial_statements_sample.csv`: **synthetic** fictional companies, same schema | ✅ |
| `reference/` | Company master and P&L bridge definition (hand-maintained) | ✅ |

## Getting the real data

1. Download from <https://www.kaggle.com/datasets/rish1203/financial-statements> (Kaggle account needed), or with the CLI:
   ```bash
   kaggle datasets download -d rish1203/financial-statements -p data/raw --unzip
   ```
2. Rename the CSV to `Financial Statements.csv` if needed.
3. In Power BI set the `RawFile` parameter to `raw\Financial Statements.csv` and refresh.
4. If any ticker in the file isn't in `reference/company_master.csv`, it still loads (shown by ticker). Add a row to give it a full name.

## Regenerating the sample

```bash
python scripts/make_sample_data.py
```
