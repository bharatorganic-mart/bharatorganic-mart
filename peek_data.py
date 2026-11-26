import pandas as pd

# Read Excel WITHOUT header row so we can see raw data
df = pd.read_excel('listings_data.xlsx', header=None)

print('Raw data - first 8 rows:')
print('=' * 60)
for i in range(min(8, len(df))):
    print(f'Row {i}:', list(df.iloc[i]))
print('=' * 60)
print(f'Total rows: {len(df)}')
