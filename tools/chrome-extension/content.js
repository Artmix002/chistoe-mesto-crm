(() => {
  const text = (node) => (node?.innerText || '').replace(/\s+/g, ' ').trim();
  const collect = () => {
    const rows = [...document.querySelectorAll('[data-marker="order-row"], a[href^="/orders/"]')]
      .map((node) => {
        const row = node.closest('[data-marker="order-row"]') || node;
        const link = row.querySelector('a[href^="/orders/"]') || node;
        const href = link?.getAttribute('href') || '';
        const match = href.match(/\/orders\/(\d+)/);
        const image = row.querySelector('img');
        const itemLink = row.querySelector('a[href*="/item/"], a[href*="_"]');
        const htmlUrl = (row.outerHTML.match(/https?:\/\/[^"'\s<>]*avito\.ru[^"'\s<>]*/i) || [])[0] ||
          (row.outerHTML.match(/(?:href|data-url|data-href)=["']([^"']*(?:\/item\/|_\d{7,})[^"']*)/i) || [])[1] || '';
        return match ? {
          id: match[1],
          url: new URL(href, location.origin).href,
          text: text(row),
          title: image?.alt || '',
          itemUrl: itemLink ? new URL(itemLink.getAttribute('href'), location.origin).href :
            (htmlUrl ? new URL(htmlUrl, location.origin).href : '')
        } : null;
      }).filter(Boolean);
    return [...new Map(rows.map((row) => [row.id, row])).values()];
  };
  const orderMatch = location.pathname.match(/^\/orders\/(\d+)/);
  if (orderMatch) {
    const links = [...document.querySelectorAll('a[href]')]
      .map((a) => a.href)
      .filter((href) => /avito\.ru\/(?:[^/]+\/)?(?:item|[\w-]+_\d{7,})/.test(href));
    const itemUrl = links.find((href) => !href.includes('/orders/')) || '';
    try {
      if (chrome.runtime?.id) chrome.runtime.sendMessage({type: 'order-detail', id: orderMatch[1], itemUrl});
    } catch (_) {}
    return;
  }
  const extractDetails = () => {
    const body = text(document.body);
    const number = body.match(/(?:Назовите номер заказа|номер заказа|этот номер)[:\s№]*([\d\s]{6,})/i);
    const article = body.match(/(?:Артикул|арт\.?|SKU)[:\s№#-]*([A-Za-zА-Яа-я0-9_-]+)/i);
    return {
      barcode: number ? number[1].replace(/\s+/g, '') : '',
      article: article ? article[1].trim() : ''
    };
  };
  const extractArticleFromAd = async () => {
    const link = [...document.querySelectorAll('a[href*="/item/"]')][0];
    if (!link) return '';
    try {
      const html = await fetch(link.href, {credentials: 'include'}).then((r) => r.text());
      const adText = new DOMParser().parseFromString(html, 'text/html')?.body?.innerText || '';
      const match = adText.match(/(?:Артикул|арт\.?|SKU)[:\s№#-]*([A-Za-zА-Яа-я0-9_-]+)/i);
      return match ? match[1].trim() : '';
    } catch (_) { return ''; }
  };
  const send = (orders) => {
    try {
      if (chrome.runtime?.id) {
        chrome.runtime.sendMessage({type: 'orders', orders, url: location.href})
          .catch(() => {});
      }
    } catch (_) {}
  };
  const enrich = async () => {
    const orders = collect();
    send(orders);
  };
  enrich();
})();
