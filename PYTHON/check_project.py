"""Structural JSON-schema checks and model binding/data checks; not a DAX engine."""
from pathlib import Path
from urllib.parse import urljoin, urldefrag
import json,re,math
import pandas as pd
BASE=Path(__file__).resolve().parents[1];ROOT=BASE
registry=json.loads((ROOT/'DOCS/schemas.json').read_text())
# Focused Draft-07 validator for the schema constraints present in the Microsoft
# report files. This is intentionally described as structural checks, not a
# certification or substitute for Power BI Desktop.
def validate(x,s,url,path='$'):
    if s is True:return []
    if s is False:return [path+': forbidden']
    if '$ref' in s:
        dest,frag=urldefrag(urljoin(url,s['$ref']))
        if dest not in registry:return [path+': unavailable schema '+dest]
        target=registry[dest]
        if frag:
            for k in frag.lstrip('/').split('/'):target=target[k.replace('~1','/').replace('~0','~')]
        return validate(x,target,dest,path)
    errors=[]
    for mode in ['allOf','anyOf','oneOf']:
        if mode in s:
            branches=[validate(x,sub,url,path) for sub in s[mode]]
            ok=sum(not a for a in branches)
            if mode=='allOf':errors.extend(e for branch in branches for e in branch)
            elif (mode=='anyOf' and not ok) or (mode=='oneOf' and ok!=1):errors.append(path+': '+mode+' did not match; '+str(branches)[:350])
    if 'not' in s and not validate(x,s['not'],url,path):errors.append(path+': not constraint')
    if 'const' in s and x!=s['const']:errors.append(path+': wrong constant '+str(x))
    if 'enum' in s and x not in s['enum']:errors.append(path+': invalid enum')
    if 'type' in s:
        types=s['type'] if isinstance(s['type'],list) else [s['type']]
        valid={'object':isinstance(x,dict),'array':isinstance(x,list),'string':isinstance(x,str),'number':isinstance(x,(int,float)) and not isinstance(x,bool),'integer':isinstance(x,int) and not isinstance(x,bool),'boolean':isinstance(x,bool),'null':x is None}
        if not any(valid[t] for t in types):return errors+[path+': incorrect type']
    if isinstance(x,dict):
        for k in s.get('required',[]):
            if k not in x:errors.append(path+': missing '+k)
        props=s.get('properties',{})
        for k,v in x.items():
            if k in props:errors+=validate(v,props[k],url,path+'.'+k)
            elif s.get('additionalProperties') is False:errors.append(path+': extra property '+k)
            elif isinstance(s.get('additionalProperties'),dict):errors+=validate(v,s['additionalProperties'],url,path+'.'+k)
        for patt,sub in s.get('patternProperties',{}).items():
            for k,v in x.items():
                if re.search(patt,k):errors+=validate(v,sub,url,path+'.'+k)
    if isinstance(x,list):
        if 'minItems' in s and len(x)<s['minItems']:errors.append(path+': too few items')
        if 'maxItems' in s and len(x)>s['maxItems']:errors.append(path+': too many items')
        if s.get('uniqueItems') and len({json.dumps(v,sort_keys=True) for v in x})!=len(x):errors.append(path+': duplicate item')
        if isinstance(s.get('items'),dict):
            for i,v in enumerate(x):errors+=validate(v,s['items'],url,path+f'[{i}]')
    if isinstance(x,str):
        for k,cmp in [('minLength',lambda n:len(x)<n),('maxLength',lambda n:len(x)>n)]:
            if k in s and cmp(s[k]):errors.append(path+': '+k)
        if 'pattern' in s and not re.search(s['pattern'],x):errors.append(path+': pattern')
    if isinstance(x,(int,float)) and not isinstance(x,bool):
        if 'minimum' in s and x<s['minimum']:errors.append(path+': below minimum')
        if 'maximum' in s and x>s['maximum']:errors.append(path+': above maximum')
    return errors
errors=[];n=0
for p in (ROOT/'POWERBI').rglob('*'):
    if p.suffix not in ['.json','.pbip','.pbir','.pbism']:continue
    d=json.loads(p.read_text());u=d.get('$schema')
    if u:
        n+=1
        if u.endswith('/visualContainer/2.14.0/schema.json') and u not in registry:
            u=u.replace('/2.14.0/','/2.4.0/') # Compatibility shape check; October 2.14 schema endpoint is not published.
            d=dict(d, **{'$schema':u}) # Validate a copy, retaining the actual report metadata.
        if u not in registry:errors.append(str(p.relative_to(ROOT))+': missing schema '+u)
        else:errors.extend(str(p.relative_to(ROOT))+': '+e for e in validate(d,registry[u],u))
m=json.loads((ROOT/'POWERBI/DigitalAurora.SemanticModel/model.bim').read_text())['model']
tables={t['name']:t for t in m['tables']};cols={t:set(c['name'] for c in d.get('columns',[])) for t,d in tables.items()}
measures={x['name'] for x in tables['KPI Measures']['measures']}
for table_name in tables:
    if table_name.casefold() == 'measures':errors.append('Reserved table name: '+table_name)
def bindings(x,where):
    if isinstance(x,dict):
        for typ,allowed in [('Column',cols),('Measure',None)]:
            if typ in x:
                f=x[typ]
                if isinstance(f,dict) and 'Expression' in f and 'Property' in f:
                    ref=f['Expression'].get('SourceRef',{});t=ref.get('Entity');c=f['Property']
                    if t and (t not in tables or (typ=='Column' and c not in cols[t]) or (typ=='Measure' and c not in measures)):errors.append(where+': missing model binding '+str((t,c)))
        for v in x.values():bindings(v,where)
    elif isinstance(x,list):
        for v in x:bindings(v,where)
for p in (ROOT/'POWERBI/DigitalAurora.Report/definition').rglob('*.json'):bindings(json.loads(p.read_text()),str(p.relative_to(ROOT)))
data={}
for t in tables.values():
    if t['name']=='KPI Measures':continue
    expression='\n'.join(t['partitions'][0]['source']['expression'])
    filename=next(a['value'] for a in t['annotations'] if a['name']=='SourceCSV')
    data[t['name']]=pd.read_csv(ROOT/'DATA'/filename)
    if set(data[t['name']].columns)!=cols[t['name']]:errors.append(t['name']+': CSV/header mismatch')
for r in m['relationships']:
    parent=data[r['toTable']][r['toColumn']];child=data[r['fromTable']][r['fromColumn']].dropna()
    if parent.duplicated().any():errors.append(r['toTable']+': duplicate dimension keys')
    if (~child.isin(parent)).any():errors.append(r['fromTable']+': orphan keys '+r['fromColumn'])
# DAX reference and delimiter lint only. An engine must still compile/evaluate it.
for me in tables['KPI Measures']['measures']:
    expression=me['expression']
    cleaned=re.sub(r'"(?:[^"]|"")*"','""',expression)
    # Use a separate pattern to avoid confusing unqualified measure names.
    for a,b,c in re.findall(r"(?:'([^']+)'|\b([A-Za-z][A-Za-z0-9_]*))\[([^\]]+)\]",cleaned):
        t=a or b
        if t not in cols or c not in cols[t]:errors.append(me['name']+': invalid DAX column '+t+'['+c+']')
    expression_without_columns=re.sub(r"(?:'[^']+'|\b[A-Za-z][A-Za-z0-9_]*)\[[^\]]+\]",'',cleaned)
    for ref in re.findall(r'\[([^\]]+)\]',expression_without_columns):
        if ref not in measures and not ref.startswith('__'):errors.append(me['name']+': unknown DAX measure '+ref)
    for a,b in [('(',')'),('[',']')]:
        if cleaned.count(a)!=cleaned.count(b):errors.append(me['name']+': unbalanced '+a+b)
# One direction filter graph must have no multiple paths between nodes.
graph={t:[] for t in tables}
for r in m['relationships']:graph[r['toTable']].append(r['fromTable'])
for source in graph:
    seen={}
    def visit(t,path):
        for child in graph[t]:
            if child in path:errors.append('relationship cycle '+str(path+[child]));continue
            seen[child]=seen.get(child,0)+1
            if seen[child]>1:errors.append('ambiguous filter paths '+source+' -> '+child)
            visit(child,path+[child])
    visit(source,[source])
result={'schema_documents_checked':n,'model_tables':len(tables),'measures_linted':len(measures),'relationships_checked':len(m['relationships']),'schema_scope':'2.14 visual containers checked for compatibility against published 2.4 structure; not 2.14 certification', 'structural_errors':errors,'desktop_runtime_verified':False,'limitations':'Structural checks and DAX references/delimiters only; no DAX compilation/execution or Power BI rendering was performed.'}
(ROOT/'DOCS/project_checks.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
if errors:raise SystemExit(1)
