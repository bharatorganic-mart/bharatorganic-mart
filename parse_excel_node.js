const XLSX = require('xlsx');
const fs = require('fs');

const workbook = XLSX.readFile('data/Bharat_Organic_Mart_Demo_Listings.xlsx');
const sheetName = workbook.SheetNames[0];
const worksheet = workbook.Sheets[sheetName];

const rawData = XLSX.utils.sheet_to_json(worksheet, { header: 1 });

console.log(`Total rows: ${rawData.length}`);

// Valid operator types
const validTypes = new Set([
    "Individual Farmers",
    "Grower Groups",
    "Contract Farming",
    "Processors & Manufacturers",
    "FPOs & Cooperatives",
    "Traders",
    "Organic Suppliers"
]);

const headerMap = {
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
};

const listings = [];
for (let i = 3; i < rawData.length; i++) {
    const row = rawData[i];
    if (!row || row.length === 0 || !row[0]) continue;

    const opType = row[0];
    // Only include valid operator types
    if (!validTypes.has(opType)) continue;

    const item = {};
    for (const [colIdx, key] of Object.entries(headerMap)) {
        const idx = parseInt(colIdx);
        let val = row[idx] !== undefined ? row[idx] : "";
        // Convert Excel date numbers to YYYY-MM-DD
        if (typeof val === 'number' && val > 40000 && val < 50000) {
            const date = new Date(Math.round((val - 25569) * 86400 * 1000));
            val = date.toISOString().split('T')[0];
        }
        item[key] = val;
    }

    item["isDemoData"] = true;
    listings.push(item);
}

fs.writeFileSync('data/clean_listings.json', JSON.stringify(listings, null, 2));
console.log(`Successfully imported ${listings.length} records from project Excel file into data/clean_listings.json.`);