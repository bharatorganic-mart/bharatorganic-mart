import openpyxl
import json

wb = openpyxl.load_workbook('data/Bharat_Organic_Mart_Demo_Listings.xlsx', data_only=True)
sheet = wb.active

rows = list(sheet.iter_rows(values_only=True))
headers = rows[2]

records = []
for row in rows[3:]:
    if not row or not row[0]:
        continue
    record = {}
    for h, val in zip(headers, row):
        if h:
            record[str(h).strip()] = val if val is not None else ""
    record["isDemoData"] = True
    records.append(record)

with open('data/listings.json', 'w') as f:
    json.dump(records, f, indent=2)

print(f"Successfully converted {len(records)} records using Python.")
