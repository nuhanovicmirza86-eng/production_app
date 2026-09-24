/* NOTIF-M1-C — background web push. Mora ostati na korijenu site-a. */
/* eslint-disable no-undef */
importScripts('https://www.gstatic.com/firebasejs/11.0.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.0.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBqGt5kstlj4f29Lj4sFyx8q6KwZOQ2zh8',
  authDomain: 'plamingo-maintenance.firebaseapp.com',
  projectId: 'plamingo-maintenance',
  storageBucket: 'plamingo-maintenance.firebasestorage.app',
  messagingSenderId: '798970225428',
  appId: '1:798970225428:web:03743a6c41f2bbe0cb1801',
});

firebase.messaging().onBackgroundMessage(function () {
  return Promise.resolve();
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({type: 'window', includeUncontrolled: true}).then((list) => {
      for (let i = 0; i < list.length; i++) {
        const client = list[i];
        if (client.url && 'focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow('/');
      }
      return undefined;
    }),
  );
});
