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
        return match ? {
          id: match[1],
          url: new URL(href, location.origin).href,
          text: text(row),
          title: image?.alt || ''
        } : null;
      }).filter(Boolean);
    return [...new Map(rows.map((row) => [row.id, row])).values()];
  };
  const send = () => {
    const orders = collect();
    chrome.runtime.sendMessage({type: 'orders', orders, url: location.href});
  };
  send();
  new MutationObserver(() => send()).observe(document.body, {childList: true, subtree: true});
})();
