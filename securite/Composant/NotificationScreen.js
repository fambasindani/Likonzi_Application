


import React, { useState, useEffect } from 'react';
import { StyleSheet, Text, View, Button } from 'react-native';
import SocketIOClient from 'socket.io-client';

const IP_ADDRESS = '192.168.68.103';
const PORT = 1200;

const NotificationScreens = () => {
  const [socket, setSocket] = useState(null);
  const [notifications, setNotifications] = useState([]);

  useEffect(() => {
    const newSocket = SocketIOClient(`http://${IP_ADDRESS}:${PORT}`);
    setSocket(newSocket);

    newSocket.on('connect', () => {
      console.log('Connected to server');
    });

    newSocket.on('notification', (data) => {
      console.log('Received notification:', data);
      setNotifications((prev) => [...prev, data]);
    });

    newSocket.on('disconnect', () => {
      console.log('Disconnected from server');
    });

    return () => {
      newSocket.disconnect();
    };

    
  }, []);

  const sendNotification = () => {
    const notification = {
      title: 'New Notification',
      message: 'This is a new notification',
    };
    socket.emit('new_notification', notification);
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Notifications</Text>
      {notifications.map((notification, index) => (
        <View key={index} style={styles.notification}>
          <Text style={styles.notificationTitle}>{notification.title}</Text>
          <Text style={styles.notificationMessage}>{notification.message}</Text>
        </View>
      ))}
      <Button title="Send Notification" onPress={sendNotification} />
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
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 20,
  },
  notification: {
    backgroundColor: '#f2f2f2',
    padding: 10,
    marginVertical: 5,
    borderRadius: 5,
  },
  notificationTitle: {
    fontSize: 16,
    fontWeight: 'bold',
  },
  notificationMessage: {
    fontSize: 14,
  },
});

export default NotificationScreens;

