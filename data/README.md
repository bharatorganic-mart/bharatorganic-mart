# Bharat Organic Mart - Data Directory

This directory contains the demo listings data for the marketplace.

## Files

- `clean_listings.json` - Structured JSON data containing all demo listings with proper categorization
- `Bharat_Organic_Mart_Demo_Listings.xlsx` - Original Excel source file

## Data Structure

Each listing includes:
- `operatorType` - Category (Individual Farmers, Grower Groups, etc.)
- `name` - Operator name
- `address` - Registered address
- `scope1/2/3` - Certification scopes
- `certBody1/2/3` - Certification bodies
- `country`, `state`, `city` - Location
- `contactPerson`, `phone`, `email`, `website` - Contact details
- `productName` / `organicCrops` - Products/crops
- `isDemoData` - Flag indicating this is demo/illustrative data

## Important Notes

1. **Demo Data Flag**: All records have `isDemoData: true` to clearly label them as illustrative data
2. **Status**: Certification status is marked as "DEMO ONLY – NOT VERIFIED"
3. **Future Integration**: This JSON structure will be connected to Supabase for live Excel uploads and admin editing

## Directory Pages

- `index.html` - Main directory page with category tabs and filters
