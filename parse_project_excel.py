import openpyxl
import json
from datetime import datetime, date

excel_path = 'data/Bharat_Organic_Mart_Demo_Listings.xlsx'
wb = openpyxl.load_workbook(excel_path, data_only=True)
sheet = wb.active

rows = list(sheet.iter_rows(values_only=True))
print(f"Total rows in sheet: {len(rows)}")

header_row_idx = 2

header_map = {
    0: "operatorType",
    1: "name",
    2: "address",
    3: "scope1",
    4: "certBody1",
    5: "scope2",
    6: "certBody2",
    7: "scope3",
    8: "certBody3",
    9: "country",
    10: "state",
    11: "city",
    12: "facilityAddress",
    13: "postalCode",
    14: "contactPerson",
    15: "phone",
    16: "email",
    17: "website",
    18: "productName",
    19: "certificationStatus",
    20: "certificationDate",
    21: "lastUpdated",
    22: "certifiedLandArea",
    23: "organicCrops",
    24: "cropCertificationStatus",
    25: "growerGroupIndicator",
    26: "certifiedArea",
    27: "dataUpdated"
}

listings = []
for idx, row in enumerate(rows[3:], start=4):
    op_type = row[0]
    name = row[1]
    # Skip header row if it was included
    if not op_type or not name or op_type == "Operator Type":
        continue

    item = {}
    for col_idx, key in header_map.items():
        if col_idx < len(row):
            val = row[col_idx]
            if isinstance(val, (datetime, date)):
                val = val.strftime('%Y-%m-%d')
            item[key] = val if val is not None else ""
        else:
            item[key] = ""

    item["isDemoData"] = True
    listings.append(item)

output_path = 'data/clean_listings.json'
with open(output_path, 'w') as f:
    json.dump(listings, f, indent=2)

print(f"Successfully imported {len(listings)} records from project Excel file into {output_path}.")