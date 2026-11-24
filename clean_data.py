import openpyxl
import json

wb = openpyxl.load_workbook('data/Bharat_Organic_Mart_Demo_Listings.xlsx', data_only=True)
sheet = wb.active

rows = list(sheet.iter_rows(values_only=True))
# Row index 2 has the actual keys
raw_headers = rows[2]

# Map column indices to clean property names
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
for row in rows[3:]:
    # Check if first column has operator type
    op_type = row[0]
    name = row[1]
    if not op_type or not name:
        continue

    item = {}
    for idx, key in header_map.items():
        if idx < len(row):
            val = row[idx]
            item[key] = val if val is not None else ""
        else:
            item[key] = ""

    item["isDemoData"] = True
    listings.append(item)

with open('data/clean_listings.json', 'w') as f:
    json.dump(listings, f, indent=2)

print(f"Successfully cleaned {len(listings)} listings.")
