"""Rebuild analytical inputs from the supplied CSVs; does not regenerate source data."""
from pathlib import Path
import json, shutil
import numpy as np
import pandas as pd

BASE=Path(__file__).resolve().parents[1]
ROOT=BASE
DATA=ROOT/'DATA'
for d in [DATA,ROOT/'PYTHON',ROOT/'SQL',ROOT/'DOCS',ROOT/'POWERBI',ROOT/'IMAGES']:
    d.mkdir(parents=True,exist_ok=True)
SRC=DATA
tables={}
for name,source in [('customers','customers'),('campaigns','campaigns'),('products','products'),('sessions','sessions'),('events','events'),('orders','orders')]:
    df=pd.read_csv(SRC/f'{source}.csv')
    tables[name]=df
    
    if (SRC/f'{source}.csv').resolve() != (DATA/f'{name}.csv').resolve():
        shutil.copyfile(SRC/f'{source}.csv',DATA/f'{name}.csv')
s=tables['sessions'].copy();e=tables['events'].copy();o=tables['orders'].copy();c=tables['customers'].copy();ca=tables['campaigns'].copy()
for df,cols in [(s,['session_start','session_end']),(e,['event_timestamp']),(o,['order_timestamp']),(c,['signup_date'])]:
    for col in cols: df[col]=pd.to_datetime(df[col],errors='raise')
o['order_status']=o.order_status.str.strip()
checks={}
def check(name,actual,expected=0):
    checks[name]={'actual':int(actual),'expected':int(expected),'passed':int(actual)==int(expected)}
for name,df in tables.items():check(f'{name}_duplicate_primary_keys',df.iloc[:,0].duplicated().sum())
for child,col,parent in [('sessions','customer_id','customers'),('sessions','campaign_id','campaigns'),('events','session_id','sessions'),('events','product_id','products'),('orders','session_id','sessions'),('orders','customer_id','customers')]:
    ids=tables[child][col].dropna();check(f'{child}_{col}_orphans',(~ids.isin(tables[parent][col])).sum())
check('negative_session_duration',(s.session_end<s.session_start).sum())
bound=e.merge(s[['session_id','session_start','session_end']],on='session_id',validate='many_to_one')
check('events_outside_session',((bound.event_timestamp<bound.session_start)|(bound.event_timestamp>bound.session_end)).sum())
purchase=e[e.event_name.eq('purchase')]
matched=purchase.merge(o,on='order_id',suffixes=('_event','_order'),validate='one_to_one')
check('purchase_order_count_difference',abs(len(purchase)-len(o)))
check('purchase_order_missing_matches',abs(len(purchase)-len(matched)))
check('purchase_order_session_mismatches',(matched.session_id_event!=matched.session_id_order).sum())
check('purchase_order_timestamp_mismatches',(matched.event_timestamp!=matched.order_timestamp).sum())
check('order_session_customer_mismatches',len(o.merge(s[['session_id','customer_id']],on='session_id').query('customer_id_x != customer_id_y').dropna(subset=['customer_id_x','customer_id_y'])))
campaign_matches=s.dropna(subset=['campaign_id']).merge(ca,on='campaign_id',suffixes=('_s','_c'),validate='many_to_one')
check('campaign_channel_mismatches',(campaign_matches.channel_s!=campaign_matches.channel_c).sum())
outside=(pd.to_datetime(campaign_matches.session_start).dt.normalize()<pd.to_datetime(campaign_matches.start_date))|(pd.to_datetime(campaign_matches.session_start).dt.normalize()>pd.to_datetime(campaign_matches.end_date))
warnings={'campaign_sessions_outside_campaign_schedule':int(outside.sum())}
f=e.pivot_table(index='session_id',columns='event_name',values='event_timestamp',aggfunc='min')
for a,b in [('view_item','add_to_cart'),('add_to_cart','begin_checkout'),('begin_checkout','purchase')]:
    check(f'{b}_missing_{a}',(f[b].notna()&f[a].isna()).sum());check(f'{b}_before_{a}',(f[b]<f[a]).sum())
ordered_view=f.view_item.notna()
ordered_cart=ordered_view&f.add_to_cart.notna()&(f.add_to_cart>=f.view_item)
ordered_checkout=ordered_cart&f.begin_checkout.notna()&(f.begin_checkout>=f.add_to_cart)
ordered_purchase=ordered_checkout&f.purchase.notna()&(f.purchase>=f.begin_checkout)
flags=pd.DataFrame({'viewed_flag':ordered_view.astype(int),'cart_flag':ordered_cart.astype(int),'checkout_flag':ordered_checkout.astype(int),'purchase_flag':ordered_purchase.astype(int)})
s=s.merge(flags,left_on='session_id',right_index=True,validate='one_to_one')
s=s.merge(e[e.event_name.eq('page_view')].groupby('session_id').size().rename('page_views'),on='session_id',how='left',validate='one_to_one')
s['page_views']=s.page_views.fillna(0).astype(int)
s['duration_seconds']=(s.session_end-s.session_start).dt.total_seconds().astype(int)
s['engaged_flag']=((s.duration_seconds>10)|(s.page_views>=2)|(s.purchase_flag==1)).astype(int)
completed=o[o.order_status.eq('Completed')].copy()
amount=completed.groupby('session_id').agg(revenue_inr=('order_value_inr','sum'),order_count=('order_id','nunique'))
s=s.merge(amount,on='session_id',how='left',validate='one_to_one')
s[['revenue_inr','order_count']]=s[['revenue_inr','order_count']].fillna(0)
s['order_count']=s.order_count.astype(int)
s=s.merge(c[['customer_id','city','state']],on='customer_id',how='left',validate='many_to_one')
s[['city','state']]=s[['city','state']].fillna('Unknown / anonymous')
s['customer_type']=np.where(s.customer_id.notna(),'Registered','Anonymous')
s['campaign_id']=s.campaign_id.fillna(0).astype(int)
s['customer_id']=s.customer_id.fillna(0).astype(int)
s['session_date']=s.session_start.dt.normalize()
first=s.sort_values(['session_start','session_id']).drop_duplicates('visitor_id').copy()
vis=first[['visitor_id','customer_id','session_date','channel','device_type','city','state','customer_type']].rename(columns={'session_date':'first_visit_date','channel':'first_channel','device_type':'first_device'})
s=s.merge(vis[['visitor_id','first_visit_date']],on='visitor_id',validate='many_to_one')
s['user_type']=np.where(s.session_date.eq(s.first_visit_date),'New','Returning')
vis['cohort_month']=vis.first_visit_date.values.astype('datetime64[M]')
vis['cohort_label']=vis.cohort_month.dt.strftime('%Y-%m')
last=s.session_date.max()
days=s[['visitor_id','session_date']].drop_duplicates().merge(vis[['visitor_id','first_visit_date']],on='visitor_id')
days['age_days']=(days.session_date-days.first_visit_date).dt.days
for day in [1,7,30]:
    retained=set(days.loc[days.age_days.eq(day),'visitor_id'])
    vis[f'eligible_d{day}']=(vis.first_visit_date<=last-pd.Timedelta(days=day)).astype(int)
    vis[f'retained_d{day}']=vis.visitor_id.isin(retained).astype(int)
agg=s.groupby('visitor_id').agg(session_count=('session_id','size'),active_days=('session_date','nunique'),lifetime_revenue_inr=('revenue_inr','sum'),lifetime_orders=('order_count','sum'))
vis=vis.merge(agg,on='visitor_id',validate='one_to_one')
vis['repeat_visitor_flag']=(vis.session_count>1).astype(int)
vis['repeat_buyer_flag']=(vis.lifetime_orders>1).astype(int)
activity=days[['visitor_id','session_date']].copy()
activity['activity_month']=activity.session_date.values.astype('datetime64[M]')
activity=activity[['visitor_id','activity_month']].drop_duplicates().merge(vis[['visitor_id','cohort_month']],on='visitor_id')
activity['month_offset']=(activity.activity_month.dt.year-activity.cohort_month.dt.year)*12+activity.activity_month.dt.month-activity.cohort_month.dt.month
activity=activity[['visitor_id','month_offset']]
dates=pd.DataFrame({'Date':pd.date_range(s.session_date.min(),s.session_date.max())})
dates['Year']=dates.Date.dt.year;dates['Month']=dates.Date.dt.strftime('%b');dates['Month Number']=dates.Date.dt.month
dates['Year Month']=dates.Date.dt.strftime('%Y-%m');dates['Year Month Sort']=dates.Date.dt.year*100+dates.Date.dt.month
dates['Quarter']='Q'+dates.Date.dt.quarter.astype(str)
ca=pd.concat([ca,pd.DataFrame([{'campaign_id':0,'campaign_name':'Unattributed / no campaign','channel':'Mixed','start_date':s.session_date.min().strftime('%Y-%m-%d'),'end_date':last.strftime('%Y-%m-%d'),'campaign_spend':0}])],ignore_index=True)
def save(df,name):
    df=df.copy()
    for col in df:
        if pd.api.types.is_datetime64_any_dtype(df[col]):
            date_only=col in ['session_date','first_visit_date','cohort_month','Date']
            df[col]=df[col].dt.strftime('%Y-%m-%d' if date_only else '%Y-%m-%d %H:%M:%S')
    df.to_csv(DATA/name,index=False,lineterminator='\n')
o=o.merge(purchase[['order_id','product_id']],on='order_id',validate='one_to_one')
save(s,'session_features.csv');save(vis,'visitor_features.csv');save(activity,'cohort_activity.csv');save(ca,'campaign_dimension.csv');save(dates,'date_dimension.csv');save(o,'orders_clean.csv');save(e,'events_clean.csv')
save(pd.DataFrame({'Stage':['Sessions','Product view','Add to cart','Checkout','Purchase'],'Stage Order':[1,2,3,4,5]}),'funnel_stages.csv')
save(pd.DataFrame({'Month Offset':range(12)}),'month_offsets.csv')
channel=s.groupby('channel').agg(sessions=('session_id','size'),orders=('order_count','sum'),revenue=('revenue_inr','sum'),engaged=('engaged_flag','mean'),checkout=('checkout_flag','sum'),purchase=('purchase_flag','sum'))
channel['conversion_rate']=channel.purchase/channel.sessions
device=s.groupby('device_type').agg(sessions=('session_id','size'),purchases=('purchase_flag','sum'),revenue=('revenue_inr','sum'));device['conversion_rate']=device.purchases/device.sessions
funnel={name:int(value) for name,value in [('Sessions',len(s)),('Product view',s.viewed_flag.sum()),('Add to cart',s.cart_flag.sum()),('Checkout',s.checkout_flag.sum()),('Purchase',s.purchase_flag.sum())]}
metrics={'total_sessions':len(s),'total_visitors':s.visitor_id.nunique(),'total_orders':len(completed),'total_revenue_inr':round(completed.order_value_inr.sum(),2),'conversion_rate':s.purchase_flag.sum()/len(s),'average_order_value_inr':round(completed.order_value_inr.mean(),2),'engagement_rate':s.engaged_flag.mean(),'average_duration_seconds':s.duration_seconds.mean(),'pages_per_session':s.page_views.mean(),'checkout_abandonment':1-s.purchase_flag.sum()/s.checkout_flag.sum(),'cart_abandonment':1-s.purchase_flag.sum()/s.cart_flag.sum(),'observation_start':str(s.session_date.min().date()),'observation_end':str(last.date()),'d1_retention':vis.loc[vis.eligible_d1.eq(1),'retained_d1'].mean(),'d7_retention':vis.loc[vis.eligible_d7.eq(1),'retained_d7'].mean(),'d30_retention':vis.loc[vis.eligible_d30.eq(1),'retained_d30'].mean()}
checks['session_order_revenue_reconciliation']={'actual':round(s.revenue_inr.sum(),2),'expected':metrics['total_revenue_inr'],'passed':abs(s.revenue_inr.sum()-completed.order_value_inr.sum())<0.01}
check('all_sessions_have_event_records',len(s)-e.session_id.nunique())
report={'metrics':metrics,'row_counts':{k:len(v) for k,v in tables.items()},'funnel':funnel,'channel':channel.reset_index().to_dict('records'),'device':device.reset_index().to_dict('records'),'checks':checks,'warnings':warnings,'limitations':['Source generator scripts were not supplied; this pipeline rebuilds features from supplied CSVs, not the original synthetic data.','Browser, signup, search and exit fields/events are absent. They are not fabricated.','Product purchase events identify one product per order but no order line amounts/quantities exist. Product revenue allocation is not supported.','First visit means first observed visit, not necessarily true acquisition. Unknown anonymous geography remains unknown.','Campaign sessions outside scheduled dates are preserved and flagged; ROAS is a diagnostic ratio, not validated causal campaign return.','Engagement uses duration >10 seconds OR >=2 page views OR purchase; this is a project rule, not a claim of GA4 use.','No Power BI Desktop / Analysis Services runtime is available here. DAX evaluation, render and interaction verification remain pending.']}
(ROOT/'DOCS'/'validation_results.json').write_text(json.dumps(report,indent=2,default=lambda x:x.item() if hasattr(x,'item') else str(x)))
if not all(v['passed'] for v in checks.values()): raise ValueError('Data integrity check failed: inspect validation_results.json')
print(json.dumps(report,indent=2,default=lambda x:x.item() if hasattr(x,'item') else str(x)))
