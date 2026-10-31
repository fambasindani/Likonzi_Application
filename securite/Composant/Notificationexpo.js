


import React, { useEffect, useState } from 'react';
import { StyleSheet, View, Text, Button } from 'react-native';
import * as Notifications from 'expo-notifications';

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: false,
    shouldSetBadge: false,
  }),
});

const Notificationexpo = () => {
  const [expoPushToken, setExpoPushToken] = useState('');
  const [notification, setNotification] = useState(false);

  useEffect(() => {
    registerForPushNotifications();
  }, []);

  const registerForPushNotifications = async () => {
    try {
      const { status: existingStatus } = await Notifications.getPermissionsAsync();
      let finalStatus = existingStatus;
      if (existingStatus !== 'granted') {
        const { status } = await Notifications.requestPermissionsAsync();
        finalStatus = status;
      }
      if (finalStatus !== 'granted') {
        alert('Failed to get push token for push notification!');
        return;
      }
      const token = (await Notifications.getExpoPushTokenAsync()).data;
      setExpoPushToken(token);
    } catch (error) {
      console.error(error);
    }
  };

  useEffect(() => {
    const subscription1 = Notifications.addNotificationReceivedListener((notification) => {
      setNotification(notification);
    });

    const subscription2 = Notifications.addNotificationResponseReceivedListener((response) => {
      console.log(response);
    });

    return () => {
      subscription1.remove();
      subscription2.remove();
    };
  }, []);

  const handleSendNotification = async () => {
    try {
      await fetch('https://exp.host/--/api/v2/push/send', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          to: expoPushToken,
          title: 'Test Notification',
          body: 'This is a test notification',
        }),
      });
    } catch (error) {
      console.error(error);
    }
  };

  return (
    <View style={styles.container}>
      <Text>Expo Push Token: {expoPushToken}</Text>
      {notification && (
        <View>
          <Text>Notification Title: {notification.request.content.title}</Text>
          <Text>Notification Body: {notification.request.content.body}</Text>
        </View>
      )}
      <Button title="Send Notification" onPress={handleSendNotification} />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
    alignItems: 'center',
    justifyContent: 'center',
  },
});

export default Notificationexpo;









