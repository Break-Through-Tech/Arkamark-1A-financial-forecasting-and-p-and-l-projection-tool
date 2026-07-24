---

> ## Challenge Advisor: Update & Finalize Your Project Overview
>
> > 💡 **These grey text instructions are just for you, the team's Challenge Advisor; please delete them once you have completed the steps below.**
>
> We've pre-populated this Challenge Project Overview page — which is what will be shared with your Break Through Tech student team in August — using the details from your submission form. You should have received an email inviting you to join this repo as a Collaborator, enabling you to add files and make edits.
> 
> In order for your project to be finalized and assigned to a team, please:
> 1. **Review all sections below** and update or expand any content as needed, making sure to address the SME Feedback in the section immediately below. Look for square brackets to find the places below that require additional inputs from you (e.g., "About [Company / Org Name]").
> 2. **Add your dataset** to the [data folder](data) in this repo.
> 3. **Close the Issue assigned to you in this repo** to let us know that you have made your edits and the overview page is ready for final review. You can do this by going to the _Issues_ tab in the top left section of the menu above, add a comment that says "CA review complete", and click the button to Close the Issue. 
>
> If you're unfamiliar with how to edit a page like this in GitHub, check out [this tutorial](https://ubc-lib-geo.github.io/gis-workshop-waml-template/content/handson/edit-readme.html) for a quick overview (start with step 2 and only edit this page), and [this guide](https://ubc-lib-geo.github.io/gis-workshop-waml-template/content/markdown.html) on how to use Markdown to compose text.
>
>
> ❌ Remember that this is a public repo. Do NOT include: Proprietary data, PII, API keys, credentials, or anything confidential.

---

## 📋 BTT Internal Evaluation Notes
*(This section is for BTT staff and CAs only — remove before sharing with students)*

### Technical Vetting
| Check | Status | Notes |
| :--- | :--- | :--- |
| Python Compatibility | 🟢 | Tech stack relies on standard statsmodels and scikit-learn libraries, perfectly suited for the BTT environment. |
| Data Readiness | 🟡 | Data integration across trial balances and macro indicators will require significant alignment and cleaning before modeling can commence. |
| Resource Check | 🟢 | Standard CPU-based models (SARIMA, XGBoost) fit comfortably within the free-tier Colab runtime. |

### Internal Scores
- **Student Fit Score:** 7/10
- **Technical Depth Score:** 8/10
- **Overall Recommendation:** REVISE

### Advisor Feedback Draft
This project offers an excellent opportunity to bridge financial domain expertise with predictive modeling. To succeed in 12 weeks: first, restrict the forecasting scope to a top-down model rather than attempting to reconcile granular trial balances; second, implement a mandatory chronological backtesting split to ensure no leakage from future periods. Please submit a revised 12-week project plan to proceed.

---

# Financial Forecasting & P&L Projection Tool

**Company / Org:** Arkamark  
**Challenge Advisor:** Ram Kumar, kumar.k@arkamark.com  
**Program:** Break Through Tech AI Studio - Fall 2026  

---

## 🏢 About Arkamark
Arkamark is a professional services firm specializing in advanced financial analytics and strategic performance management. The team aims to modernize their financial planning processes by transitioning from manual reporting to automated, data-driven forecasting.

---

## 🎯 The Challenge
### Project Summary
This project involves developing a predictive model to forecast product-line sales and project comprehensive income statements, including EBIT, for the next two fiscal years. By leveraging ten years of historical operational data alongside macroeconomic indicators, the team will create a robust forecasting tool that provides actionable insights for future financial planning.

### Success Criteria
Primary: forecast accuracy (MAPE, RMSE, and MAE on a held-out backtest window, target MAPE under ~10%). Secondary: internally consistent two-year forward P&L, explainability of drivers, and a working documented forecasting tool.

### Project Milestones
Use these milestones to guide your work. Your team will create a GitHub Projects board to track tasks within each milestone.
| Month | Milestone | Key Activities |
|-------|-----------|----------------|
| **September** | Data Exploration & Preprocessing | Data ingestion, handling missing values in trial balances, normalizing macroeconomic time series, and conducting outlier analysis. |
| **October** | Feature Engineering & Baseline Modeling | Constructing seasonal lags, rolling averages, feature correlation mapping, and training baseline SARIMA and linear models. |
| **November** | Model Optimization & Evaluation | Performing grid search for hyperparameter tuning on gradient-boosted trees and conducting rigorous backtesting on historical hold-out sets. |
| **December** | Insights, Deliverables & Presentation | Finalizing the Streamlit dashboard, documenting model limitations, and presenting the projected P&L to company stakeholders. |

> **Note for the team:** Please create a GitHub Projects board in this repository to break these milestones into weekly tasks. Go to the **Projects** tab → **New project** → Choose **Board** → Add columns for each month.

---

## 📊 Dataset
**Name and Source:** Arkamark Historical Financial Repository  
**Format:** CSV and Parquet  
**Size:** under 1gb  
**Location:** Provided via secure partner portal; refer to onboarding documentation for access tokens.

### Key Details
- Ten years of historical financial and operational data, including monthly sales by product line, annual income statements, trial balances, and macroeconomic indicators (oil prices, interest rates).
- Preprocessing must account for calendar-based seasonality, currency fluctuations, and the normalization of heterogeneous data sources to ensure temporal consistency.

---

## 🛠️ Suggested Approach
**ML Problem Type:** Time Series Regression  
**Recommended Libraries:**
- SARIMA/ETS
- gradient-boosted trees
- regularized regression
- Streamlit
- Python (implied by Google Colab usage)
**Evaluation Metrics:** MAPE (Target < 10%), RMSE, MAE, and P&L internal consistency checks.

---

## 📚 Resources to Get Started
The following resources will help your team understand the problem space and potential technical approaches for this project:
**Background Reading:**
- Financial Statement Analysis Principles (CFA Institute Guidelines)
- Time Series Forecasting for Business (Forecasting: Principles and Practice, Hyndman)
**Technical Tutorials:**
- Scikit-learn Time Series Cross-Validation Documentation
- Streamlit "Getting Started" Building Data Dashboards
**Code Examples:**
- Statsmodels SARIMAX implementation notebooks
- XGBoost/LightGBM time-series regression tutorials

---

## 🤝 How We'll Work Together
**Check-ins:** During our biweekly 60-min AI Studio Lab Section meeting block (2nd and 4th week of every month)  
**Communication:** Slack and Corporate Email  
**Response time:** 48-hour response window for non-urgent queries  
**Recommended Tools:**
- **Coding:** Google Colab Free Tier  
- **Collaboration:** GitHub, Notion  
- **Virtual Meetings:** Zoom, Google Meet  

---

## 🚀 Getting Started
1. **Review this overview document** and note any questions for our first meeting.
2. **Begin reviewing the dataset** using the link provided in the Dataset section.
3. **Read the GitHub Projects documentation** [here](https://docs.github.com/en/issues/planning-and-tracking-with-projects/learning-about-projects/about-projects).

I'm excited to work with you!

---

## ❓ Questions?
Please bring any questions to our first meeting during the week of August 24th (Break Through Tech's Bridge to Studio - Session B).
