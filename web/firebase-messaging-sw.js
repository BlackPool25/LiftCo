// firebase-messaging-sw.js - Service Worker for Firebase Cloud Messaging
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

// Firebase configuration
firebase.initializeApp({
    apiKey: "AIzaSyBMxb4Kbs69CiEtLZsiEgVfI3vfrqY9Yi8",
    authDomain: "liftco.firebaseapp.com",
    projectId: "liftco",
    storageBucket: "liftco.firebasestorage.app",
    messagingSenderId: "447275736592",
    appId: "1:447275736592:web:df8b4231556c7307b4f495"
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
    console.log('[firebase-messaging-sw.js] Received background message:', payload);

    const notificationTitle = payload.notification?.title || 'LiftCo';
    const notificationOptions = {
        body: payload.notification?.body || 'You have a new notification',
        icon: '/icons/Icon-192.png',
        badge: '/icons/Icon-192.png',
        data: payload.data
    };

    self.registration.showNotification(notificationTitle, notificationOptions);
});
