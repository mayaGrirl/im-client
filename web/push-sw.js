// Web Push Service Worker for IM Client
// Handles background push notifications for incoming calls

self.addEventListener('install', (event) => {
  console.log('[Push SW] Installing service worker...');
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  console.log('[Push SW] Service worker activated');
  event.waitUntil(clients.claim());
});

// Handle push events (background notifications)
self.addEventListener('push', (event) => {
  console.log('[Push SW] Push event received');

  let data = {
    title: 'IM',
    body: 'You have a new notification',
    type: 'message',
    // Private call fields
    callId: null,
    callerId: null,
    callerName: '',
    callerAvatar: '',
    callType: 0,
    // Group call fields
    groupId: null,
    groupName: '',
    initiatorId: null,
    initiatorName: '',
    initiatorAvatar: ''
  };

  try {
    if (event.data) {
      data = { ...data, ...event.data.json() };
    }
  } catch (e) {
    console.error('[Push SW] Error parsing push data:', e);
  }

  console.log('[Push SW] Notification data:', data);

  // Build notification options
  const options = {
    body: data.body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: data.type === 'incoming_call' ? `call-${data.callId}` : `msg-${Date.now()}`,
    requireInteraction: data.type === 'incoming_call', // Keep call notification until user interacts
    vibrate: [200, 100, 200, 100, 200], // Vibration pattern
    data: data,
    actions: []
  };

  // Add action buttons for incoming calls (private)
  if (data.type === 'incoming_call') {
    options.actions = [
      { action: 'answer', title: 'Answer', icon: '/icons/call-answer.png' },
      { action: 'reject', title: 'Reject', icon: '/icons/call-reject.png' }
    ];
    options.body = data.callType === 2
      ? `${data.callerName} is video calling you`
      : `${data.callerName} is calling you`;
  }

  // Add action buttons for incoming group calls
  if (data.type === 'incoming_group_call') {
    options.tag = `group-call-${data.callId}`;
    options.actions = [
      { action: 'join', title: 'Join', icon: '/icons/call-answer.png' },
      { action: 'dismiss', title: 'Dismiss', icon: '/icons/call-reject.png' }
    ];
    const callTypeName = data.callType === 2 ? 'video' : 'voice';
    options.body = `${data.initiatorName} started a group ${callTypeName} call in ${data.groupName}`;
  }

  event.waitUntil(
    self.registration.showNotification(data.title, options)
  );
});

// Handle notification click
self.addEventListener('notificationclick', (event) => {
  console.log('[Push SW] Notification clicked:', event.action);

  const notification = event.notification;
  const data = notification.data || {};

  notification.close();

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      // Check if app is already open
      for (const client of clientList) {
        if ('focus' in client) {
          // Send message to the client about the action
          client.postMessage({
            type: 'notification_click',
            action: event.action,
            data: data
          });
          return client.focus();
        }
      }

      // If app is not open, open it
      if (clients.openWindow) {
        let url = '/';
        if (data.type === 'incoming_call' && event.action === 'answer') {
          url = `/?action=answer_call&callId=${data.callId}`;
        } else if (data.type === 'incoming_call' && event.action === 'reject') {
          url = `/?action=reject_call&callId=${data.callId}`;
        } else if (data.type === 'incoming_group_call' && event.action === 'join') {
          url = `/?action=join_group_call&callId=${data.callId}&groupId=${data.groupId}&callType=${data.callType}`;
        } else if (data.type === 'incoming_group_call') {
          // Default: open to the group chat
          url = `/?action=open_group&groupId=${data.groupId}`;
        }
        return clients.openWindow(url);
      }
    })
  );
});

// Handle notification close
self.addEventListener('notificationclose', (event) => {
  console.log('[Push SW] Notification closed');
  const data = event.notification.data || {};

  // If incoming call notification was dismissed without action, notify the app
  if (data.type === 'incoming_call' || data.type === 'incoming_group_call') {
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        client.postMessage({
          type: 'notification_dismissed',
          data: data
        });
      }
    });
  }
});

// Handle messages from the main app
self.addEventListener('message', (event) => {
  console.log('[Push SW] Message received:', event.data);

  if (event.data && event.data.type === 'cancel_call_notification') {
    // Cancel the call notification when call is ended/cancelled
    const callId = event.data.callId;
    self.registration.getNotifications({ tag: `call-${callId}` }).then((notifications) => {
      notifications.forEach((notification) => notification.close());
    });
  }

  if (event.data && event.data.type === 'cancel_group_call_notification') {
    // Cancel the group call notification when call is ended/cancelled
    const callId = event.data.callId;
    self.registration.getNotifications({ tag: `group-call-${callId}` }).then((notifications) => {
      notifications.forEach((notification) => notification.close());
    });
  }
});
