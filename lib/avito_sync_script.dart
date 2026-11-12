const avitoSyncScript = r'''#!/usr/bin/env python3
"""Collect active Avito listings through the user's Safari session.

Prints a JSON array of {url, title, price, article, images} to stdout.
"""
import base64
import json
import subprocess
import sys
import time

PROFILE_URL = "https://www.avito.ru/profile/items/active/all"
PAGE_URL = PROFILE_URL + "?p=%s&s=4"

COLLECT_JS = """(()=>{const out=Array.from(document.querySelectorAll('[data-marker="item-main-info"] a[href]')).map(a=>a.getAttribute('href'));window.scrollBy(0,2400);return JSON.stringify(out)})()"""

ITEM_JS = """(()=>{try{
const x=new XMLHttpRequest();x.open('GET',__PATH__,false);x.send();
const html=x.responseText;
const doc=new DOMParser().parseFromString(html,'text/html');
const price=(doc.querySelector('[data-marker="item-view/item-price"]')||{}).innerText||'';
let s=html.split('\\\\u003c').join('<').split('\\\\u003e').join('>');
const ps=Array.from(s.matchAll(/<p>(.*?)<\\/p>/g)).map(m=>m[1].replace(/<[^>]+>/g,'').trim()).filter(Boolean);
let article='';
for(let i=ps.length-1;i>=0&&i>=ps.length-4;i--){if(/^\d{3,6}$/.test(ps[i])){article=ps[i];break;}}
if(!article){const am=s.match(/(?:артикул|арт\.?)\s*[:№-]?\s*(\d{3,6})/i);if(am)article=am[1];}
const imgs=[];const re=/https:\\/\\/[0-9]+\\.img\\.avito\\.st\\/image\\/[^"'\\\\ ]+/g;let m;
while((m=re.exec(s))!==null){if(imgs.indexOf(m[0])<0)imgs.push(m[0]);}
return JSON.stringify({price:price.trim(),article:article,imgs:imgs.slice(0,6),title:(doc.querySelector('h1')||{}).innerText||''});
}catch(e){return JSON.stringify({error:String(e)})}})()"""


def osa(js, url=None, delay=0):
    b64 = base64.b64encode(js.encode("utf-8")).decode("ascii")
    if url:
        nav = 'set URL of current tab of front window to "%s"\n  activate\n  delay %s' % (url, delay)
    else:
        nav = "activate\n  delay %s" % delay
    script = (
        'tell application "Safari"\n'
        "  %s\n"
        '  return (do JavaScript "eval(atob(\'%s\'))" in current tab of front window)\n'
        "end tell" % (nav, b64)
    )
    result = subprocess.run(
        ["osascript", "-e", script], capture_output=True, text=True, timeout=180
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "osascript failed")
    return result.stdout.strip()


def collect_links(limit=None):
    links = []
    seen = set()
    for page in range(1, 15):
        osa("window.scrollTo(0,0);", url=PAGE_URL % page, delay=8)
        raw = osa(COLLECT_JS, delay=1)
        try:
            batch = json.loads(raw)
        except Exception:
            batch = []
        added = 0
        for href in batch:
            if href and href not in seen:
                seen.add(href)
                links.append(href)
                added += 1
        print(json.dumps({"page": page, "links": len(links)}), file=sys.stderr)
        if limit and len(links) >= limit:
            return links[:limit]
        if added == 0:
            break
        time.sleep(0.5)
    return links


def extract(path):
    js = ITEM_JS.replace("__PATH__", json.dumps(path))
    raw = osa(js, delay=0.15)
    try:
        data = json.loads(raw)
    except Exception:
        data = {"error": "bad json", "raw": raw[:200]}
    data["url"] = "https://www.avito.ru" + path
    return data


def main():
    limit = int(sys.argv[1]) if len(sys.argv) > 1 else None
    links = collect_links(limit)
    print(json.dumps({"links": len(links)}), file=sys.stderr)
    out = []
    for index, path in enumerate(links):
        try:
            item = extract(path)
        except Exception as exc:
            item = {"url": path, "error": str(exc)}
        out.append(item)
        print(json.dumps({"done": index + 1, "total": len(links)}), file=sys.stderr)
        time.sleep(0.25)
    print(json.dumps(out, ensure_ascii=False))


if __name__ == "__main__":
    main()
''';
