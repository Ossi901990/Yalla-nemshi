// Firebase Messaging service worker
// Replace the firebaseConfig values with your project’s web config (same as main.dart for web).

importScripts('https://www.gstatic.com/firebasejs/10.11.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.11.1/firebase-messaging-compat.js');

// TODO: fill these in with your Firebase web config
const firebaseConfig = {
  apiKey: "AIzaSyAeeUDsBUghrf5gkD2NHZnd7UxSWzZ39u8",
  authDomain: "yalla-nemshi-app.firebaseapp.com",
  projectId: "yalla-nemshi-app",
  storageBucket: "yalla-nemshi-app.firebasestorage.app",
  messagingSenderId: "403871427941",
  appId: "1:403871427941:web:6a5e07328b4e5db5d9458c",
  measurementId: "G-V4QBMB71TM"
};

firebase.initializeApp(firebaseConfig);
const messaging = firebase.messaging();

// Optional background notification handler
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Background message received', payload);
  const notificationTitle = payload.notification?.title || 'Notification';
  const notificationOptions = {
    body: payload.notification?.body,
    icon: payload.notification?.icon,
  };
  self.registration.showNotification(notificationTitle, notificationOptions);
});
