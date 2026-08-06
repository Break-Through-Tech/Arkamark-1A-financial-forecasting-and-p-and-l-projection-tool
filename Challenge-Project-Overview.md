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
**AI Studio Coach:** Anshul Rehpade, anshul.rehpade@breakthroughtech.org   
**Program:** Break Through Tech AI Studio - Fall 2026  

---

## 🏢 About Arkamark
Arkamark is a professional services firm specializing in advanced financial analytics and strategic performance management. The team aims to modernize their financial planning processes by transitioning from manual reporting to automated, data-driven forecasting.

---

## 🎯 The Challenge
### Project Summary
In this project, you will use ten years of historical financial and operational data — monthly sales by product line, annual income statements and trial balances, and macroeconomic indicators such as oil prices and interest rates and time-series forecasting and regression techniques (e.g., SARIMA/ETS, gradient-boosted trees, and regularized regression) to build a model that forecasts product-line sales and projects a full income statement — including expected EBIT — for the next two fiscal years. This will help our company address the challenge of data-driven financial planning: anticipating revenue and profitability by product line under changing macroeconomic conditions, so leadership can budget, set realistic targets, and allocate resources with confidence.

### Success Criteria
• Primary — forecast accuracy: MAPE, RMSE, and MAE on a held-out backtest window for each product line. Target: beat the seasonal-naive baseline, ideally MAPE under ~10% on each line at the annual level.
• Secondary — coherent financials: a complete, internally consistent two-year forward P&L whose revenue ties to the sales forecast and that produces a defensible EBIT projection.
• Explainability: the team can explain which drivers move the forecast and show how EBIT responds under at least two macro scenarios.
• Definition of done (December): a working, documented forecasting tool; a two-year forecast of sales by product line; a projected P&L with expected EBIT; and a clear write-up of assumptions and limitations.

### Stretch Goals
• Probabilistic forecasts: prediction intervals via quantile models or a Monte Carlo simulation over the macro drivers, instead of single point estimates.
• Extend the projection beyond the P&L to a forecast balance sheet and cash flow, reusing the trial-balance structure already provided.
• Driver-based / causal modeling: estimate the elasticity of equipment sales to interest rates and oil prices.
• Interactive dashboard (e.g., Streamlit) where a user changes a rate or oil assumption and watches the forecast P&L update live.
• Anomaly detection that flags structural shocks in the history (the 2020 demand drop, the 2022 cost spike).
• An LLM-generated executive summary that narrates the forecast and its key risks in plain English.

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
**Name and Source:** [TBD] 
**Format:** Excel (.xlsx)
**Size:** under 1gb  
**Location:** [TBD]

### Key Details
- [TBD]
  
---

## 🛠️ Suggested Approach

**ML Problem Type:** Regression, NLP, Time Series Analysis, Deep Learning / Neural Networks, Large Language Models (LLMs) / Generative AI 

**Recommended Libraries:**
- [e.g., pandas, scikit-learn, TensorFlow, Hugging Face]

**Evaluation Metrics:**
- [e.g., Accuracy, Precision/Recall, RMSE, BLEU score]

---

## 📚 Resources to Get Started

The following resources will help your team understand the problem space and potential technical approaches for this project:

**Background Reading:**
- [e.g., Link to an article or blog post about the problem domain]
- [e.g., Link to an industry report or case study]

**Technical Tutorials:**
- [e.g., Link to a free tutorial on the ML technique(s) involved]
- [e.g., Link to documentation for a key library or tool]

**Code Examples:**
- [e.g., Link to a relevant GitHub repo]
- [e.g., Link to a sample implementation or starter code]

**Other:**
- [Links to any additional resources — e.g., papers, videos, podcasts, etc.]

*Feel free to explore beyond these, and share anything interesting you find with me!*

---

## 🤝 How We'll Work Together

**Official check-ins:** During our biweekly 45-minute AI Studio Lab Section meeting block (2nd and 4th week of every month)

 **Other ways to reach out to me with questions:** 
* [e.g., Your team's channel within Break Through Tech’s Discord space]
* [e.g., Email; please copy your teammates and AI Studio Coach]
* [e.g., Request a team check-in on Zoom]
* [Note: I will aim to respond within 48 hours. Please reach out to your AI Studio Coach with urgent questions.]

> 💡 **Challenge Advisor: Please update the above based on your availability and preference. If you are not able to answer questions or meet with fellows outside of the biweekly Lab Section check-ins, simply write in "N/A (only available during the official check-in times)"**

**Recommended free coding / collaboration tools**
* […]
* […]

---

## 🚀 Getting Started

1. **Review this overview document** and note any questions for our first meeting
2. **Begin reviewing the dataset** using the link above
3. **Read the GitHub Projects documentation** [here](https://docs.github.com/en/issues/planning-and-tracking-with-projects/learning-about-projects/about-projects)

I’m excited to work with you!

---

## ❓ Questions?

Please bring any questions to our first meeting during the week of August 24th (Break Through Tech’s Bridge to Studio - Session C). 
