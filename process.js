const XLSX = require('xlsx');
const fs = require('fs');

const workbook = XLSX.readFile('data/Bharat_Organic_Mart_Demo_Listings.xlsx');
const sheet = workbook.Sheets[workbook.SheetNames[0]];

// Read rows as arrays of cell values
const rawData = XLSX.utils.sheet_to_json(sheet, { header: 1 });

// Row index 2 (3rd row) has the actual header names:
const headers = rawData[2];

const records = [];

for (let i = 3; i < rawData.length; i++) {
  const row = rawData[i];
  if (!row || row.length === 0 || !row[0]) continue; // skip empty rows

  const record = {};
  headers.forEach((header, index) => {
    if (header) {
      record[header.trim()] = row[index] !== undefined ? row[index] : "";
    }
  });

  // Tag explicitly as demo data as requested by requirement 8
  record["isDemoData"] = true;
  records.push(record);
}

fs.writeFileSync('data/listings.json', JSON.stringify(records, null, 2));
console.log(`Processed ${records.length} records successfully.`);
