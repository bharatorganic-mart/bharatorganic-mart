const XLSX = require('xlsx');
const fs = require('fs');
const path = require('path');

const workbook = XLSX.readFile('data/Bharat_Organic_Mart_Demo_Listings.xlsx');
const sheetName = workbook.SheetNames[0]; // Assuming the first sheet is the Demo Listings
const worksheet = workbook.Sheets[sheetName];
const jsonData = XLSX.utils.sheet_to_json(worksheet);

fs.writeFileSync('data/listings.json', JSON.stringify(jsonData, null, 2));
console.log('Successfully converted Excel to JSON');
