# Financial Forecasting & P&L Projection Tool

**Company / Org:** Arkamark  
**Challenge Advisor:** Ram Kumar, kumar.k@arkamark.com     
**AI Studio Coach:** Anshul Rehpade, anshul.rehpade@breakthroughtech.org   
**Program:** Break Through Tech AI Studio - Fall 2026  

---

## 🏢 About Arkamark
Arkamark is a professional services firm specializing in advanced financial analytics and strategic performance management. The team aims to modernize their financial planning processes by transitioning from manual reporting to automated, data-driven forecasting.

---

## 🎯 The Challenge

**Note:** The dataset originally planned for this project is still being finalized. See the Dataset section below for what you'll actually be working with this month — the modeling approach and goals below still apply.

### Project Summary
In this project, you will use ten years of historical financial and operational data — monthly sales by product line, annual income statements and trial balances, and macroeconomic indicators such as oil prices and interest rates and time-series forecasting and regression techniques (e.g., SARIMA/ETS, gradient-boosted trees, and regularized regression) to build a model that forecasts product-line sales and projects a full income statement — including expected EBIT — for the next two fiscal years. This will help our company address the challenge of data-driven financial planning: anticipating revenue and profitability by product line under changing macroeconomic conditions, so leadership can budget, set realistic targets, and allocate resources with confidence.

### Success Criteria
- Primary — forecast accuracy: MAPE, RMSE, and MAE on a held-out backtest window for each product line. Target: beat the seasonal-naive baseline, ideally MAPE under ~10% on each line at the annual level.
- Secondary — coherent financials: a complete, internally consistent two-year forward P&L whose revenue ties to the sales forecast and that produces a defensible EBIT projection.
- Explainability: the team can explain which drivers move the forecast and show how EBIT responds under at least two macro scenarios.
- Definition of done (December): a working, documented forecasting tool; a two-year forecast of sales by product line; a projected P&L with expected EBIT; and a clear write-up of assumptions and limitations.

### Stretch Goals
- Probabilistic forecasts: prediction intervals via quantile models or a Monte Carlo simulation over the macro drivers, instead of single point estimates.
- Extend the projection beyond the P&L to a forecast balance sheet and cash flow, reusing the trial-balance structure already provided.
- Driver-based / causal modeling: estimate the elasticity of equipment sales to interest rates and oil prices.
- Interactive dashboard (e.g., Streamlit) where a user changes a rate or oil assumption and watches the forecast P&L update live.
- Anomaly detection that flags structural shocks in the history (the 2020 demand drop, the 2022 cost spike).
- An LLM-generated executive summary that narrates the forecast and its key risks in plain English.

### Project Milestones
Use these milestones to guide your work. Your team will create a GitHub Projects board to track tasks within each milestone.

| Month | Milestone | Key Activities |
|---|---|---|
| September | Data foundation & exploration | • Load and clean all datasets; agree on a shared data dictionary and project structure.<br>• Exploratory analysis: visualize each product line's trend and seasonality; decompose the series into trend / seasonal / residual.<br>• Quantify how sales relate to the macro drivers (oil price, interest rate, construction index), including lagged effects.<br>• Reconcile the historical P&L to the trial balances to understand how sales flow down to EBIT.<br>• Establish naive and seasonal-naive baseline forecasts as the benchmark to beat. |
| October | Modeling | • Feature engineering: calendar/seasonal terms, lagged macro variables, rolling statistics.<br>• Build and compare sales-forecasting models per product line: baseline → classical time series (SARIMA/ETS) → ML regression (gradient boosting, regularized linear).<br>• Build the "sales-to-P&L" engine: translate forecasted revenue into COGS, operating expenses, and EBIT using the historical margin structure.<br>• Produce a first end-to-end two-year forecast (sales by product line + projected P&L). |
| November | Validation, scenarios & delivery | • Backtest with rolling/expanding-window cross-validation; analyze errors and select final models.<br>• Run scenario and sensitivity analysis (e.g., high- vs. low-interest-rate paths, an oil-price shock).<br>• Package the forecasting tool (clean notebook or a simple dashboard) and finalize the two-year forecast P&L with EBIT and product-line sales.<br>• Prepare the final presentation and a written summary of methodology, assumptions, and limitations. |

> **Note for the team:** Please create a GitHub Projects board in this repository to break these milestones into weekly tasks. Go to the **Projects** tab → **New project** → Choose **Board** → Add columns for each month.

---

## 📊 Dataset
**Name and Source:** Two public substitute datasets, while the original Arkamark historical financial data is finalized on the company's end:
1. Corporación Favorita Store Sales (Kaggle) — for the sales-forecasting half of the project
2. Financial Data of 4400+ Public Companies (Kaggle) — for the income-statement / EBIT half

**Format:** CSV
**Size:** under 1GB combined
**Location:**
- Sales data: https://www.kaggle.com/competitions/store-sales-time-series-forecasting
- Financial statement data: https://www.kaggle.com/datasets/qks1lver/financial-data-of-4400-public-companies

### Key Details
- While Arkamark's proprietary financial data is being finalized, these two datasets together let your team practice the full original project shape: forecast sales, then translate that forecast into a projected income statement.
- **Dataset 1 (sales forecasting):** daily sales by store and product family (~33 categories, standing in for "product line") from Corporación Favorita, a large grocery retailer, across multiple years. Includes a daily oil-price series as a built-in macroeconomic driver, plus store metadata, holidays/events, and promotions.
- **Dataset 2 (income statement / EBIT):** multi-year income statements, balance sheets, and cash flow statements for 4,400+ public companies — including revenue, cost of revenue, gross profit, operating expenses, and operating income (EBIT). Use this to study realistic margin structures (COGS %, opex %) and build the "sales forecast → P&L → EBIT" translation logic the original brief called for, independent of which specific company's sales you're forecasting.
- **How to combine them:** forecast Favorita's sales as usual, then apply a margin structure derived from Dataset 2 (e.g., median COGS % and opex % for a comparable retail company) to convert that sales forecast into a simulated income statement with an EBIT line. This isn't a perfect substitute for Arkamark's actual financials, but it exercises the same modeling skill.
- **Scope note:** neither dataset includes trial balances, so the trial-balance reconciliation piece of the original brief stays out of scope until real data arrives.
- Want an interest-rate series to pair with the oil data? See [FRED](https://fred.stlouisfed.org) (Federal Reserve Economic Data).
  
---

## 🛠️ Suggested Approach

**ML Problem Type:** Regression, NLP, Time Series Analysis, Deep Learning / Neural Networks, Large Language Models (LLMs) / Generative AI

**Recommended Libraries:**
- pandas, numpy for data wrangling
- statsmodels (SARIMA/ETS)
- scikit-learn (regularized regression)
- XGBoost or LightGBM (gradient-boosted trees)
- matplotlib/seaborn for visualization

**Evaluation Metrics:**
- MAPE, RMSE, MAE on a held-out backtest window
- Benchmarked against a seasonal-naive baseline

---

## 📚 Resources to Get Started

The following resources will help your team understand the problem space and potential technical approaches for this project:

**Background Reading:**
- Financial Statement Analysis Principles (CFA Institute Guidelines)
- Forecasting: Principles and Practice (Hyndman & Athanasopoulos) — free online

**Technical Tutorials:**
- Statsmodels SARIMAX documentation
- Scikit-learn Time Series Cross-Validation docs

**Code Examples:**
- Statsmodels SARIMAX implementation notebooks
- XGBoost/LightGBM time-series regression tutorials

**Other:**
- Kaggle "Store Sales - Time Series Forecasting" competition notebooks — real fellow-submitted solutions using this exact dataset, useful for seeing different modeling approaches

*Feel free to explore beyond these, and share anything interesting you find with me!*

---
## 🤝 How We'll Work Together

**Official check-ins:** During our biweekly 45-minute AI Studio Lab Section meeting block (2nd and 4th week of every month)

**Other ways to reach out to me with questions:**
* N/A (only available during the official check-in times)
* While the Challenge Advisor's regular availability is being confirmed, please route project questions to your AI Studio Coach in the meantime.
* I will aim to respond within 48 hours during official check-ins. Please reach out to your AI Studio Coach with urgent questions.

**Recommended free coding / collaboration tools**
* Google Colab — free cloud notebooks, no local setup needed
* Jupyter — for local development if preferred

---

## 🚀 Getting Started

1. **Review this overview document** and note any questions for our first meeting
2. **Begin reviewing the dataset** using the link above
3. **Read the GitHub Projects documentation** [here](https://docs.github.com/en/issues/planning-and-tracking-with-projects/learning-about-projects/about-projects)

I’m excited to work with you!

---

## ❓ Questions?

Please bring any questions to our first meeting during the week of August 24th (Break Through Tech’s Bridge to Studio - Session C). 
