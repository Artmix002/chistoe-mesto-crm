(() => {
  const text = (node) => (node?.innerText || '').replace(/\s+/g, ' ').trim();
  const deliveryService = (body) => {
    const services = [
      ['Почта России', /почта\s+россии/i],
      ['Яндекс', /яндекс(?:\s+доставка|\s+маркет)?/i],
      ['СДЭК', /сд[эе]к/i],
      ['Boxberry', /boxberry/i],
      ['5Post', /5\s*post/i],
      ['DPD', /\bdpd\b/i],
      ['DHL', /\bdhl\b/i],
      ['Авито', /авито\s+доставк/i],
    ];
    return services.find(([, pattern]) => pattern.test(body))?.[0] || '';
  };
  const send = (message) => {
    try { if (chrome.runtime?.id) chrome.runtime.sendMessage(message).catch(() => {}); } catch (_) {}
  };
  const orderId = (location.pathname.match(/^\/orders\/(\d+)/) || [])[1];
  const heartbeat = () => fetch('http://127.0.0.1:47621/avito/extension/heartbeat', {
    method: 'POST',
    headers: {'content-type': 'application/json'},
    body: JSON.stringify({url: location.href}),
  }).catch(() => {});
  heartbeat();

  if (orderId) {
    const reportOrder = () => {
      const body = document.body?.innerText || '';
      const match = body.match(/(?:^|\n)Заказ\s*\n?([^\n]+?)\s+\d+\s*[×xх]\s*[\d\s\u00a0]+₽/m);
      if (!match) return false;
      const barcode = (body.match(/Назовите (?:номер заказа|этот номер):\s*([\d\s]+)/i) || [])[1] || '';
      const pvz = (
        body.match(/(?:Примерный срок доставки|Срок хранения)[^\n]*?\s((?:Россия|г\.|Республика)[^\n]+?)(?=\s+График работы|$)/i) ||
        body.match(/(?:Пункт выдачи|Адрес пункта выдачи|ПВЗ)\s*[:\n]\s*([^\n]{5,160})/i) ||
        body.match(/(?:Куда доставить|Получение)\s*\n+([^\n]{5,160})/i) ||
        []
      )[1] || '';
      send({
        type: 'order-ready',
        id: orderId,
        productTitle: match[1].trim(),
        barcode: barcode.replace(/\s+/g, ''),
        pvz: pvz.replace(/\s+/g, ' ').trim(),
        shippingService: deliveryService(body),
      });
      return true;
    };
    let tries = 0;
    const waitForOrder = () => { if (reportOrder() || ++tries >= 20) return; setTimeout(waitForOrder, 500); };
    waitForOrder();
    chrome.runtime.onMessage.addListener((message) => {
      if (message?.type !== 'open-order-product') return;
      const normalize = (value) => String(value || '').replace(/\s+/g, ' ').trim().toLowerCase();
      const wanted = normalize(message.productTitle);
      const candidates = [...document.querySelectorAll('a, button, [role="link"], span, div')]
        .filter((node) => normalize(node.innerText).startsWith(wanted))
        .filter((node) => node.getClientRects().length)
        .sort((a, b) => normalize(a.innerText).length - normalize(b.innerText).length);
      if (!candidates.length) return send({type: 'product-open-failed', id: orderId});
      candidates[0].click();
    });
    return;
  }

  const listingId = (location.pathname.match(/_(\d{7,})(?:$|[/?#])/) || [])[1];
  if (listingId) {
    const maybeImportListing = async () => {
      let request;
      try {
        const response = await fetch(
          `http://127.0.0.1:47621/avito/import/request?url=${encodeURIComponent(location.href)}`,
        );
        if (!response.ok) return;
        request = await response.json();
      } catch (_) {
        return;
      }
      if (!request?.pending) return;

      const normalize = (value) => String(value || '').replace(/\s+/g, ' ').trim();
      const body = document.body?.innerText || '';
      const title = normalize(document.querySelector('h1')?.innerText);
      const price = (body.match(/(?<!\d)([\d\s\u00a0]{2,})\s*₽/) || [])[1] || '';
      const descriptionHeading = [...document.querySelectorAll('h1,h2,h3')]
        .find((node) => normalize(node.innerText).toLowerCase() === 'описание');
      const description = normalize(
        descriptionHeading?.parentElement?.parentElement?.innerText ||
        descriptionHeading?.parentElement?.innerText,
      );
      const descriptionText = description
        .replace(/^описание\s*/i, '')
        .replace(/Показать полностью$/i, '')
        .trim();
      const category = normalize(
        document.querySelector('[data-marker*="breadcrumbs" i]')?.innerText ||
        [...document.querySelectorAll('nav a')].map((node) => node.innerText).join(' '),
      ).split(' ').filter(Boolean).at(-1) || '';
      const attributes = {};
      for (const node of document.querySelectorAll('li, [data-marker*="item-params" i]')) {
        const lines = (node.innerText || '').split('\n').map((line) => normalize(line)).filter(Boolean);
        if (lines.length < 2 || lines[0].length > 50 || lines[1].length > 120) continue;
        if (!attributes[lines[0]]) attributes[lines[0]] = lines.slice(1).join(', ');
      }
      // Avito adds logos, badges and recommendations to the page as ordinary
      // images. Only the item gallery contains the listing's own photographs.
      const itemView = document.querySelector('[data-marker="item-view"]');
      const galleryImages = itemView
        ? [...itemView.querySelectorAll(
          '[data-marker^="item-view/gallery"] img, ' +
          '[data-marker^="item-view/preview-image"] img, ' +
          '[data-marker^="image-frame"] img',
        )]
        : [];
      const imageUrls = galleryImages
        .flatMap((image) => {
          const srcset = image.getAttribute('srcset') || '';
          const best = srcset.split(',').map((item) => item.trim().split(/\s+/)[0]).filter(Boolean).at(-1);
          return [best, image.currentSrc, image.src];
        })
        .filter((url) =>
          /^https?:\/\//.test(url) &&
          /(?:avito\.st|avito\.ru).*(?:^|[./])image(?:[/?]|$)/i.test(url),
        );
      const photos = [...new Set(imageUrls)].slice(0, 10);
      const article = (
        descriptionText.match(/(?:артикул|арт\.?|sku)\s*[:№#-]?\s*([a-zа-я0-9_-]{3,})/i) ||
        []
      )[1] || '';
      try {
        await fetch('http://127.0.0.1:47621/avito/import/listing', {
          method: 'POST',
          headers: {'content-type': 'application/json'},
          body: JSON.stringify({
            requestId: request.requestId,
            itemId: listingId,
            itemUrl: location.href,
            title,
            price: price.replace(/\s+/g, ''),
            description: descriptionText,
            category,
            attributes,
            article,
            photos,
          }),
        });
      } catch (_) {}
    };
    setTimeout(maybeImportListing, 1500);
    let tries = 0;
    const reportListing = () => {
      const descriptionHeading = [...document.querySelectorAll('h1,h2,h3')]
        .find((node) => text(node).toLowerCase() === 'описание');
      const description = text(descriptionHeading?.parentElement?.parentElement) || text(document.body);
      const explicit = description.match(/(?:артикул|арт\.?|sku)\s*[:№#-]?\s*([a-zа-я0-9_-]{3,})/i);
      const numbers = [...description.matchAll(/(?<!\d)(\d{3,6})(?!\d)/g)].map((match) => match[1]);
      if ((!description || description.length < 10) && ++tries < 20) return setTimeout(reportListing, 500);
      send({type: 'listing-ready', itemId: listingId, itemUrl: location.href, article: explicit?.[1] || numbers.at(-1) || '', articleCandidates: numbers});
    };
    reportListing();
    return;
  }

  const collect = () => [...document.querySelectorAll('[data-marker="order-row"], a[href^="/orders/"]')]
    .map((node) => {
      const row = node.closest('[data-marker="order-row"]') || node;
      const link = row.querySelector('a[href^="/orders/"]') || node;
      const href = link?.getAttribute('href') || '';
      const id = (href.match(/\/orders\/(\d+)/) || [])[1];
      const image = row.querySelector('img');
      const orderText = (row.innerText || '')
        .replace(/\n+/g, ' | ')
        .replace(/[\t ]+/g, ' ')
        .replace(/(?:\s*\|\s*){2,}/g, ' | ')
        .trim();
      return id ? {id, url: new URL(href, location.origin).href, text: orderText, title: image?.alt || ''} : null;
    }).filter(Boolean);
  let lastSignature = '';
  const reportOrders = () => {
    const orders = [...new Map(collect().map((row) => [row.id, row])).values()];
    const signature = orders.map((row) => row.id).join(',');
    if (!orders.length || signature === lastSignature) return;
    lastSignature = signature;
    send({type: 'orders', orders});
  };
  // Other parts of Avito mutate constantly (chat, promos), so waiting for a
  // quiet DOM never completes. The order list itself is fully visible after a
  // short fixed delay; retry once if Avito is still loading it.
  setTimeout(reportOrders, 4000);
  setTimeout(reportOrders, 8000);
})();
