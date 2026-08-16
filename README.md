# Pharmaceutical Demand Forecasting & Statistical Time-Series Analysis

Forecasts monthly pharmacy demand across 8 drug categories, identifies trend and seasonality
statistically (not just visually), and produces a stock-risk table for the next 1-3 months —
combining SQL, exploratory data analysis, classical statistical testing, time-series forecasting,
and a machine learning comparison.

## Business problem

Given ~6 years of historical pharmacy sales, predict next-month and 3-month-ahead demand per
drug category, and flag which categories are trending toward a stockout or an overstock. The
project is organized as a sequence of notebooks, each building on validated output from the
previous one rather than restarting from raw data.

## Dataset

Daily/weekly/monthly/hourly point-of-sale data from a single pharmacy (Jan 2014 - Oct 2019).
Sales are broken out by 8 ATC drug classification codes rather than individual SKUs, region, or
customer:

| Code  | Category                                        |
|-------|--------------------------------------------------|
| M01AB | Anti-inflammatory (acetic acid derivatives)      |
| M01AE | Anti-inflammatory (propionic acid derivatives)   |
| N02BA | Analgesics - salicylic acid derivatives          |
| N02BE | Analgesics - pyrazolones and anilides            |
| N05B  | Anxiolytics                                      |
| N05C  | Hypnotics and sedatives                          |
| R03   | Anti-asthmatic and COPD drugs                    |
| R06   | Antihistamines                                   |

## Repository structure

```
pharma-demand-forecasting/
├── data/
│   ├── salesdaily.csv, saleshourly.csv, salesweekly.csv, salesmonthly.csv   (raw)
│   └── processed/            # long-format CSVs, SQLite db, backtest results, forecasts
├── sql/
│   ├── schema.sql            # dim_category + fact_sales
│   └── sales_analysis.sql    # rolling averages, MoM/YoY growth, ranking, gap detection
├── notebooks/
│   ├── 01_data_cleaning.ipynb
│   ├── 02_eda.ipynb
│   ├── 03_statistical_analysis.ipynb
│   ├── 04_time_series_forecasting.ipynb
│   ├── 05_ml_comparison.ipynb
│   └── 06_model_evaluation.ipynb
├── images/                   # figures exported from the notebooks
├── requirements.txt
└── README.md
```

## Methodology

1. **Data cleaning** — reshape all 4 granularities to long format, load into SQLite
   (`dim_category` + `fact_sales`), validate daily-rollup against the reported monthly totals.
2. **EDA** — volume by category, trend, month-of-year and weekday/hour seasonality, missing-date
   and outlier detection, cross-category correlation.
3. **Statistical analysis** — seasonal decomposition (additive/multiplicative, auto-selected),
   ADF + KPSS stationarity testing, differencing, ACF/PACF, Ljung-Box, OLS trend significance
   with 95% confidence intervals, and formal hypothesis tests (Welch's t-test + Mann-Whitney) of
   the seasonal patterns found in EDA.
4. **Time-series forecasting** — naive, seasonal naive, moving average, Holt-Winters, and
   `auto_arima`-selected SARIMA, evaluated with **expanding-window walk-forward backtesting**
   (not a single train/test split — there are only 69 monthly observations per category) at 1-
   and 3-month horizons.
5. **ML comparison** — lag (1/2/3/6/12 month), rolling mean/std (3/6/12 month), and calendar
   (month sin/cos, quarter) features, fed into XGBoost with direct (not recursive) multi-horizon
   forecasting, backtested on the same expanding-window origins as the statistical models for a
   fair comparison.
6. **Evaluation** — MAE/RMSE/MAPE across all 6 models, best model selected **per category**
   rather than one algorithm forced on all 8, final forecast + stock-risk table.

## Key findings

- **SARIMA wins overall** (18.4% MAPE at 1-month, pooled across categories) but not universally —
  Holt-Winters wins the two most strongly seasonal categories (R03, R06), and a 3-month moving
  average wins the one category (N02BA) with a simple, consistent decline. XGBoost never wins a
  single category outright: with only 69 monthly points per series, there isn't enough data for
  a generic gradient-boosted model to out-learn models with seasonal/autoregressive structure
  already built in.
- **Real seasonality, not noise**: R03 (respiratory) demand is significantly higher in winter
  (p < 0.0001), R06 (antihistamines) significantly higher in spring (p < 0.0001) — confirmed with
  two independent hypothesis tests, not just visual inspection of a boxplot.
- **A trailing-average "risk" comparison can be misleading for seasonal categories.** R03's
  October forecast looks like a +143% spike against its summer-trough trailing average, but is
  actually flat (-3.4%) year-over-year. The final table reports both figures rather than only the
  one that looks more dramatic.
- **Data quality issues were found and fixed, not assumed away**: the raw monthly file has a
  zeroed-out January 2017 for 7 of 8 categories (patched from the daily-granularity rollup before
  any downstream analysis), and the final month in the daily/hourly files (October 2019) is
  partial, not a real demand collapse — both handled explicitly rather than silently distorting
  the seasonality and trend estimates.

## Running it

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
jupyter notebook notebooks/
```

Notebooks are numbered and meant to run in order — each writes intermediate output
(`data/processed/`) that the next one reads.
