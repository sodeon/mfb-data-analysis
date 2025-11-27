import yfinance as yf
import pandas as pd

def get_apple_stock_csv():
    # Download Apple (AAPL) data from 2015-01-01 to present
    # auto_adjust=True ensures we get the split-adjusted price which is standard for analysis
    data = yf.download("AAPL", start="2015-01-01", auto_adjust=True)

    if not data.empty:
        # Reset index to move 'Date' from index to a column
        df = data.reset_index()

        # Select the 'Date' and 'Close' columns
        # Note: yfinance columns might be MultiIndex, we ensure we select the right one
        try:
            # For recent yfinance versions
            df = df[['Date', 'Close']]
        except KeyError:
             # Fallback if structure differs
            df = df.iloc[:, [0, 3]] # Assuming Date is 1st and Close is 4th

        # Rename columns to match requested format: date, price (USD)
        df.columns = ['date', 'price (USD)']

        # Format date as YYYY-MM-DD
        df['date'] = pd.to_datetime(df['date']).dt.strftime('%Y-%m-%d')

        # Round price to 2 decimal places
        df['price (USD)'] = df['price (USD)'].round(2)

        # Save to CSV without the index
        filename = "apple_daily_stock_2015_present.csv"
        df.to_csv(filename, index=False)
        print(f"Successfully created {filename}")
        print(df.head())
        print(df.tail())
    else:
        print("No data found.")

if __name__ == "__main__":
    get_apple_stock_csv()
