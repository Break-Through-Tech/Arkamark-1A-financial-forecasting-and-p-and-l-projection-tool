from pathlib import Path
import pandas as pd

project_root = Path(__file__).resolve().parent.parent
file_path = (
    project_root
    / "data"
    / "store sales time series forecasting"
    / "train.csv"
)

sales = pd.read_csv(file_path)

print("Shape:", sales.shape)
print("\nColumns:")
print(sales.columns.tolist())
print("\nFirst five rows:")
print(sales.head())
print("\nMissing values:")
print(sales.isna().sum())

sales["date"] = pd.to_datetime(sales["date"])

family_summary = (
    sales.groupby("family", as_index=False)["sales"]
    .sum()
    .sort_values("sales", ascending=False)
)

print("\nTotal sales by product family:")
print(family_summary.to_string(index=False))

grocery = sales[sales["family"] == "GROCERY I"].copy()

daily_grocery = (
    grocery.groupby("date", as_index=False)["sales"]
    .sum()
    .sort_values("date")
)

print("\nGROCERY I daily data:")
print(daily_grocery.head())
print(daily_grocery.tail())
print("\nDate range:", daily_grocery["date"].min(), "to", daily_grocery["date"].max())
print("Number of days:", len(daily_grocery))
print("Average daily sales:", daily_grocery["sales"].mean())

from sklearn.metrics import mean_absolute_error, mean_squared_error
import numpy as np

season_length = 7
test_size = 28

train = daily_grocery.iloc[:-test_size].copy()
test = daily_grocery.iloc[-test_size:].copy()

test["prediction"] = train["sales"].iloc[-test_size - season_length:-season_length].values

mae = mean_absolute_error(test["sales"], test["prediction"])
rmse = np.sqrt(mean_squared_error(test["sales"], test["prediction"]))

non_zero_actuals = test["sales"] != 0
mape = (
    np.mean(
        np.abs(
            (test.loc[non_zero_actuals, "sales"]
             - test.loc[non_zero_actuals, "prediction"])
            / test.loc[non_zero_actuals, "sales"]
        )
    )
    * 100
)

print("\nSeasonal-naive baseline:")
print("MAE:", mae)
print("RMSE:", rmse)
print("MAPE:", mape, "%")