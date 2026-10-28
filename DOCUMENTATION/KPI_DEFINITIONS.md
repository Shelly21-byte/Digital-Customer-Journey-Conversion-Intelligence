# Metric definitions

The complete current formulas are in DAX_Measures.dax and the semantic model. README.md documents definitions, baseline totals and material caveats. Definitions preserved from the uploaded project include session-level conversion and funnel flags, distinct visitor counts, completed order-grain revenue, first-observed cohorts, eligible D1/D7/D30 retention, and observed-history cohort revenue.

V5 changes are detailed in REVISION_NOTES.md. Campaign peers are selected identified campaigns; at least 100 selected sessions qualify for the score. Dense ranking shares genuine ties. Top 10 uses campaign ID as a deterministic tie-breaker for membership. Neither the score nor the diagnostic ROAS demonstrates causal lift or actual profitability.

Calendar monthly retention totals are weighted by eligible visitor counts. Mature cells without returns show zero; incomplete months show blank. Comparison labels use a full previous equal-length interval and stay blank without complete history. Use contiguous date ranges for comparisons.
