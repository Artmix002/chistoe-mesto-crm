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
  const extractDetails = () => {
    const body = text(document.body);
    const number = body.match(/(?:Назовите номер заказа|номер заказа|этот номер)[:\s№]*([\d\s]{6,})/i);
    const article = body.match(/(?:Артикул|арт\.?|SKU)[:\s№#-]*([A-Za-zА-Яа-я0-9_-]+)/i);
    return {
      barcode: number ? number[1].replace(/\s+/g, '') : '',
      article: article ? article[1].trim() : ''
    };
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
    for (const order of orders) {
      const link = [...document.querySelectorAll('a[href^="/orders/"]')]
        .find((a) => a.getAttribute('href')?.includes(`/orders/${order.id}`));
      if (!link) continue;
      link.click();
      await new Promise((resolve) => setTimeout(resolve, 1200));
      Object.assign(order, extractDetails());
      history.back();
      await new Promise((resolve) => setTimeout(resolve, 900));
    }
    send(orders);
  };
  enrich();
})();
