const endpoint = 'http://127.0.0.1:47621/avito/orders';
let queue = [];
let batch = [];
let current = null;
let timer = null;

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

const send = async (orders) => {
  await fetch(endpoint, {method: 'POST', headers: {'content-type': 'application/json'}, body: JSON.stringify({source: 'chrome-extension', orders})}).catch(() => {});
};
const loadClosedOrderNumbers = async () => {
  try {
    const response = await fetch(`${endpoint}/closed`);
    if (!response.ok) return new Set();
    const data = await response.json();
    return new Set((data?.closedOrderNumbers || []).map((number) => String(number)));
  } catch (_) {
    // A missing CRM must not block the normal collection flow.
    return new Set();
  }
};
const armTimeout = (milliseconds = 20000) => {
  clearTimeout(timer);
  timer = setTimeout(() => finishCurrent(), milliseconds);
};
const finishCurrent = async () => {
  if (!current) return;
  clearTimeout(timer);
  const done = current;
  current = null;
  for (const tabId of [done.orderTabId, done.listingTabId]) if (tabId) chrome.tabs.remove(tabId).catch(() => {});
  const index = batch.findIndex((order) => order.id === done.order.id);
  if (index >= 0) batch[index] = done.order;
  // Store each completed lookup immediately. A large order list must not keep
  // the user waiting for the final item before showing the first article.
  await send([done.order]);
  await next();
};
const next = async () => {
  if (current) return;
  if (!queue.length && batch.length) {
    const result = batch;
    batch = [];
    await send(result);
    return;
  }
  if (!queue.length) return;
  const order = queue.shift();
  // Avito opens the listing only for a click in a foreground tab.  In a
  // background tab Chrome treats the same click as a blocked popup, so the
  // item URL (and therefore its stable ID) never reaches the CRM.
  const tab = await chrome.tabs.create({url: order.url, active: true});
  current = {order, orderTabId: tab.id, listingTabId: null};
  armTimeout();
};

const applyListingUrl = (itemUrl) => {
  if (!current || !itemUrl) return;
  current.order.itemUrl = itemUrl;
  current.order.itemId = (itemUrl.match(/_(\d{7,})(?:$|[/?#])/) || [])[1] || '';
  finishCurrent();
};

// The product control opens the listing with window.open. Run this in Avito's
// own page context to capture that URL before Chrome treats it as a popup.
const captureOrderProductUrl = async (productTitle) => new Promise((resolve) => {
  const normalize = (value) => String(value || '').replace(/\s+/g, ' ').trim().toLowerCase();
  const wanted = normalize(productTitle);
  const originalOpen = window.open;
  let finished = false;
  const finish = (url = '') => {
    if (finished) return;
    finished = true;
    window.open = originalOpen;
    resolve(url);
  };
  window.open = (url) => {
    const absolute = new URL(String(url || ''), location.href).href;
    finish(/avito\.ru\/.+_\d{7,}(?:$|[/?#])/.test(absolute) ? absolute : '');
    return null;
  };
  // Avito attaches the product action to the exact title span. Wider
  // containers have the same text but their click opens unrelated controls.
  const clickProduct = (attempt = 0) => {
    // The title becomes visible before Avito hydrates its click handler. Wait
    // for the actual interactive node instead of marking the order unmatched.
    const exactTitles = [...document.querySelectorAll('*')]
      .filter((node) => normalize(node.textContent) === wanted)
      .filter((node) => node.getClientRects().length)
      .sort((a, b) => a.querySelectorAll('*').length - b.querySelectorAll('*').length);
    const candidates = exactTitles.length ? exactTitles : [...document.querySelectorAll('a, button, [role="link"], span, div')]
      // In the current Avito layout the same block reads, for example,
      // "Пуховик Женский 1 x 1600 ₽".  The article title is still its first
      // part; requiring equality made the control invisible to the crawler.
      .filter((node) => normalize(node.innerText).startsWith(wanted))
      .filter((node) => node.getClientRects().length)
      .sort((a, b) => normalize(a.innerText).length - normalize(b.innerText).length);
    if (!candidates.length) {
      if (attempt < 20) return setTimeout(() => clickProduct(attempt + 1), 500);
      return finish('');
    }
    // The item control is normally inside a regular link. Read that URL before
    // clicking; this avoids relying on Avito's popup implementation.
    const linked = candidates
      .map((node) => node.closest('a[href]') || node.querySelector?.('a[href]'))
      .map((link) => link?.getAttribute('href') || '')
      .map((href) => href ? new URL(href, location.href).href : '')
      .find((href) => /avito\.ru\/.+_\d{7,}(?:$|[/?#])/.test(href));
    if (linked) return finish(linked);
    const target = candidates[0];
    // Avito's product row is handled on pointer/mouse events rather than on
    // the element's simple click() method. Reproduce the full browser event
    // sequence so the route to the listing is opened and its URL can be read.
    for (const type of ['pointerdown', 'mousedown', 'pointerup', 'mouseup', 'click']) {
      target.dispatchEvent(new MouseEvent(type, {
        bubbles: true,
        cancelable: true,
        view: window,
      }));
    }
    setTimeout(() => finish(''), 7000);
  };
  clickProduct();
});

const findOrderProductPoint = (productTitle) => {
  const normalize = (value) => String(value || '').replace(/\s+/g, ' ').trim().toLowerCase();
  const wanted = normalize(productTitle);
  const candidates = [...document.querySelectorAll('a, button, [role="link"], div, span')]
    .filter((node) => normalize(node.innerText).startsWith(wanted))
    .filter((node) => node.getClientRects().length)
    .sort((a, b) => normalize(a.innerText).length - normalize(b.innerText).length);
  if (!candidates.length) return null;
  const rect = candidates[0].getBoundingClientRect();
  return rect.width && rect.height ? {x: rect.left + rect.width / 2, y: rect.top + rect.height / 2} : null;
};

const clickWithBrowserMouse = async (tabId, point) => {
  if (!point) return false;
  const target = {tabId};
  try {
    await chrome.debugger.attach(target, '1.3');
    await chrome.debugger.sendCommand(target, 'Input.dispatchMouseEvent', {type: 'mouseMoved', x: point.x, y: point.y});
    await chrome.debugger.sendCommand(target, 'Input.dispatchMouseEvent', {type: 'mousePressed', x: point.x, y: point.y, button: 'left', clickCount: 1});
    await chrome.debugger.sendCommand(target, 'Input.dispatchMouseEvent', {type: 'mouseReleased', x: point.x, y: point.y, button: 'left', clickCount: 1});
    return true;
  } catch (_) {
    return false;
  } finally {
    chrome.debugger.detach(target).catch(() => {});
  }
};

const readOrder = async () => {
  for (let attempt = 0; attempt < 20; attempt += 1) {
    const body = document.body?.innerText || '';
    // Avito alternates between placing the title and quantity on one line and
    // splitting them over several nodes. Capture the block after "Заказ".
    const match = body.match(
      /(?:^|\n)Заказ\s*\n+([\s\S]{1,250}?)\s*\n+\d+\s*[×xх]\s*[\d\s\u00a0]+₽/m,
    ) || body.match(
      /(?:^|\n)Заказ\s*\n?(.+?)\s+\d+\s*[×xх]\s*[\d\s\u00a0]+₽/m,
    );
    if (match) {
      const barcode = (body.match(/Назовите (?:номер заказа|этот номер):\s*([\d\s]+)/i) || [])[1] || '';
      const pvz = (
        // Current Avito orders put the exact pickup point directly after the
        // estimated delivery date, before its opening hours.
        body.match(/(?:Примерный срок доставки|Срок хранения)[^\n]*?\s((?:Россия|г\.|Республика)[^\n]+?)(?=\s+График работы|$)/i) ||
        body.match(/(?:Пункт выдачи|Адрес пункта выдачи|ПВЗ)\s*[:\n]\s*([^\n]{5,160})/i) ||
        body.match(/(?:Куда доставить|Получение)\s*\n+([^\n]{5,160})/i) ||
        []
      )[1] || '';
      const productTitle = match[1].split('\n').map((line) => line.trim()).filter(Boolean).join(' ');
      if (productTitle) return {
        productTitle,
        barcode: barcode.replace(/\s+/g, ''),
        pvz: pvz.replace(/\s+/g, ' ').trim(),
        shippingService: deliveryService(body),
      };
    }
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  return {productTitle: '', barcode: '', pvz: '', shippingService: ''};
};

const openListingFromCurrentOrder = (details) => {
  if (!current || !details?.productTitle) return finishCurrent();
  // The content script and executeScript fallback can both report the same
  // page. Only the first report may advance the queue.
  if (current.orderDetailsOpened) return;
  current.orderDetailsOpened = true;
  current.order.barcode = details.barcode || '';
  current.order.pvz = details.pvz || '';
  current.order.shippingService = details.shippingService || '';
  chrome.scripting.executeScript({
    target: {tabId: current.orderTabId},
    func: findOrderProductPoint,
    args: [details.productTitle],
  }).then((results) => {
    if (!current) return;
    clickWithBrowserMouse(current.orderTabId, results?.[0]?.result).then((clicked) => {
      if (!clicked && current && !current.listingTabId) finishCurrent();
    });
  }).catch(finishCurrent);
};

chrome.runtime.onMessage.addListener((message, sender) => {
  if (message?.type === 'orders' && Array.isArray(message.orders)) {
    if (current || queue.length) return;
    batch = message.orders.map((order) => ({...order, article: '', itemUrl: '', itemId: ''}));
    // Snapshot closed statuses before opening the first order. This prevents a
    // long run from repeatedly checking historical completed/cancelled orders.
    loadClosedOrderNumbers().then((closedNumbers) => {
      queue = batch
        .filter((order) => !closedNumbers.has(String(order.id)))
        .map((order) => ({...order}));
      next();
    });
    return;
  }
  if (message?.type === 'order-ready') {
    if (current && sender.tab?.id === current.orderTabId) {
      openListingFromCurrentOrder(message);
    }
    return;
  }
  if (message?.type === 'product-open-failed') return;
});

// Chrome reports the destination URL even when Avito opens it through an
// internal React handler rather than a visible <a href> element.
chrome.webNavigation.onCreatedNavigationTarget.addListener((details) => {
  if (!current || details.sourceTabId !== current.orderTabId) return;
  if (!/avito\.ru\/.+_\d{7,}(?:$|[/?#])/.test(details.url)) return;
  current.listingTabId = details.tabId;
  applyListingUrl(details.url);
});

chrome.tabs.onCreated.addListener((tab) => {
  // Avito does not consistently populate openerTabId for its product tab.
  // Processing is strictly sequential, so the first new Avito tab belongs to
  // the order currently being read.
  if (!current || current.listingTabId || tab.id === current.orderTabId) return;
  current.listingTabId = tab.id;
  const itemUrl = tab.pendingUrl || tab.url || '';
  if (/avito\.ru\/.+_\d{7,}(?:$|[/?#])/.test(itemUrl)) {
    applyListingUrl(itemUrl);
  } else {
    armTimeout();
  }
});

chrome.tabs.onUpdated.addListener((tabId, changeInfo) => {
  if (!current || changeInfo.status !== 'complete') return;
  if (tabId === current.orderTabId && !current.orderOpened) {
    current.orderOpened = true;
    chrome.scripting.executeScript({target: {tabId}, func: readOrder})
      .then((results) => openListingFromCurrentOrder(results?.[0]?.result))
      .catch(finishCurrent);
    return;
  }
  // Some Avito flows omit both openerTabId and navigation-target metadata.
  // While an order is being handled, any other completed Avito listing tab is
  // therefore the item selected in that order.
  if (tabId !== current.orderTabId) {
    chrome.tabs.get(tabId).then((tab) => {
      const url = tab.url || '';
      if (/avito\.ru\/.+_\d{7,}(?:$|[/?#])/.test(url)) applyListingUrl(url);
    }).catch(() => {});
  }
});
