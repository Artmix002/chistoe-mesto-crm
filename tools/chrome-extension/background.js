const endpoint = 'http://127.0.0.1:47621/avito/orders';
const pending = new Map();
let activeBatch = [];

const send = (orders) => fetch(endpoint, {method: 'POST', headers: {'content-type': 'application/json'},
  body: JSON.stringify({source: 'chrome-extension', orders})}).catch(() => {});

const readDetails = async (orders) => {
  activeBatch = orders;
  for (const order of orders) {
    const tab = await chrome.tabs.create({url: order.url, active: false});
    pending.set(tab.id, {order, tabId: tab.id});
    setTimeout(() => {
      if (!pending.has(tab.id)) return;
      pending.delete(tab.id);
      chrome.tabs.remove(tab.id).catch(() => {});
      if (!pending.size) send(activeBatch);
    }, 25000);
  }
};

chrome.tabs.onRemoved.addListener((tabId) => pending.delete(tabId));

chrome.runtime.onMessage.addListener((message, sender) => {
  if (message?.type !== 'orders' || !Array.isArray(message.orders)) return;
  readDetails(message.orders).then(() => {
    if (!pending.size) send(message.orders);
  });
});

chrome.runtime.onMessage.addListener((message, sender) => {
  if (message?.type !== 'order-detail' || !sender.tab?.id) return;
  const entry = pending.get(sender.tab.id);
  if (!entry) return;
  if (!message.itemUrl && !message.article) return;
  entry.order.itemUrl = message.itemUrl || '';
  entry.order.article = message.article || '';
  entry.order.productTitle = message.productTitle || '';
  entry.order.productPrice = message.productPrice || '';
  pending.delete(sender.tab.id);
  chrome.tabs.remove(sender.tab.id).catch(() => {});
  if (!pending.size) send(activeBatch);
});
