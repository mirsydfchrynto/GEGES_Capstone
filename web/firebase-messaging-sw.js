importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-app.js');
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging.js');

firebase.initializeApp({
  apiKey: "AIzaSyDtqlNucmw3zjqL1RE-uz6_UcD4Kv1hPoo",
  projectId: "geges-smartbarber-project",
  messagingSenderId: "51527807075",
  appId: "1:51527807075:web:4943c3694db47a720a4856"
});

const messaging = firebase.messaging();

// Optional: Handle background messages
messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  // Customize notification here
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
