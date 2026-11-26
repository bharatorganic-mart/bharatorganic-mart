import pandas as pd
import numpy as np
from supabase import create_client
from datetime import datetime

# 1. Your Project URL
SUPABASE_URL = 'https://syxrvkiqrvbecqdkyphs.supabase.co'
# 2. Your Secret Service Role Key
SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN5eHJ2a2lxcnZiZWNxZGt5cGhzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5NTUzMDY0OSwiZXhwIjoyMTExMTA2NjQ5fQ.B3oL4zVK9UlJVxbfQds0gb2iN4DE_M566-1AMpoVnI0'

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

# Map your Excel headers → Database column names
COLUMN_MAP = {
    'Operator Type': 'operator_type',
    'Name': 'name',
    'Registered / Business Address': 'address',
    'Scope Certified 1': 'scope_1',
    'Certification Body 1': 'cert_body_1',
    'Scope Certified 2': 'scope_2',
    'Certification Body 2': 'cert_body_2',
    'Scope Certified 3': 'scope_3',
    'Certification Body 3': 'cert_body_3',
    'Country': 'country',
    'State': 'state',
    'City': 'city',
    'Farm / Facility Address': 'facility_address',
    'Postal Code': 'postal_code',
    'Contact Person': 'contact_person',
    'Phone': 'phone',
    'Email': 'email',
    'Website': 'website',
    'Product Name': 'product_name',
    'Certification Status': 'certification_status',
    'Certification Date': 'certification_date',
    'Last Updated': 'last_updated',
    'Certified Land Area': 'certified_land_area',
    'Organic Crops': 'organic_crops',
    'Crop Certification Status': 'crop_certification_status',
    'Grower Group Indicator': 'grower_group_indicator',
    'Certified Area': 'certified_area',
}

def clean_column_name(name):
    """Strip whitespace from column names."""
    if isinstance(name, str):
        return name.strip()
    return name

def upload_data(file_path):
    # Read Excel - skip first 2 rows (title + section groups), use row 3 as headers
    df = pd.read_excel(file_path, header=2, skiprows=[0, 1])

    # Clean column names (remove extra spaces)
    df.columns = [clean_column_name(c) for c in df.columns]

    print('Columns found in your Excel file:')
    for col in df.columns:
        print(f'  - {col}')

    # Rename columns to match database names
    df = df.rename(columns=COLUMN_MAP)

    # Replace NaN with None (JSON null)
    df = df.replace({np.nan: None})

    # Convert to list of dicts
    data = df.to_dict(orient='records')

    # Convert datetimes to strings
    for row in data:
        for key, value in row.items():
            if isinstance(value, (pd.Timestamp, datetime)):
                row[key] = value.strftime('%Y-%m-%d')

    # Add is_demo_data = true to every row
    for row in data:
        row['is_demo_data'] = True

    print(f'\nTotal rows to upload: {len(data)}')
    print(f'First row preview: {data[0] if data else "empty"}')

    # Drop columns that don't exist in the database
    db_columns = list(COLUMN_MAP.values()) + ['is_demo_data']
    data = [{k: v for k, v in row.items() if k in db_columns} for row in data]

    # Push to Supabase
    try:
        response = supabase.table('directory_listings').insert(data).execute()
        print(f'\n✅ Successfully uploaded {len(data)} records!')
    except Exception as e:
        print(f'\n❌ Error: {e}')

if __name__ == "__main__":
    upload_data('/Users/garry/Documents/GitHub/bharatorganic-mart/listings_data.xlsx')
