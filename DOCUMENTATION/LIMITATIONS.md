# Limitations

- Source generator scripts were not supplied; this pipeline rebuilds features from supplied CSVs, not the original synthetic data.
- Browser, signup, search and exit fields/events are absent. They are not fabricated.
- Product purchase events identify one product per order but no order line amounts/quantities exist. The chart reports purchase-attributed order revenue rather than itemized product sales.
- First visit means first observed visit, not necessarily true acquisition. Unknown anonymous geography remains unknown.
- Campaign sessions outside scheduled dates are preserved and flagged; ROAS is a diagnostic ratio, not validated causal campaign return.
- Engagement uses duration >10 seconds OR >=2 page views OR purchase; this is a project rule, not a claim of GA4 use.
- No Power BI Desktop / Analysis Services runtime is available here. DAX evaluation, render and interaction verification remain pending.

No original generation code was supplied. MySQL scripts and DAX need local execution.
No measured uplift, accuracy score, causal conclusion or flawless-dashboard claim is made.
