const endpoint = 'http://127.0.0.1:47621/avito/orders';

chrome.runtime.onMessage.addListener((message, sender) => {
  if (message?.type !== 'orders' || !Array.isArray(message.orders)) return;
  fetch(endpoint, {
    method: 'POST',
    headers: {'content-type': 'application/json'},
    body: JSON.stringify({source: 'chrome-extension', tabId: sender.tab?.id ?? null,
      url: message.url || '', orders: message.orders})
  }).catch(() => {
    // CRM may not be running yet; the next page mutation retries the delivery.
  });
});
