import pandas as pd

# Read your Excel file
df = pd.read_excel('listings_data.xlsx')

print('Your Excel column headers:')
print('-' * 50)
for i, col in enumerate(df.columns, 1):
    print(f'{i}. {col}')
print('-' * 50)
print(f'Total columns: {len(df.columns)}')
print(f'Total rows: {len(df)}')
