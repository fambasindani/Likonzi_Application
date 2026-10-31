import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import io from 'socket.io-client';

const API_URL = 'http://192.168.68.103:1200';

const NotificationsScreen = () => {
  const [notifications, setNotifications] = useState([]);
  const [socket, setSocket] = useState(null);

  useEffect(() => {
    const newSocket = io(API_URL);
    setSocket(newSocket);

    newSocket.on('connect', () => {
      console.log('Connected to server');
    });

    newSocket.on('new_notification', (data) => {
      setNotifications((prevNotifications) => [
        ...prevNotifications,
        {
          id: data.id,
          nom: data.nom,
          postnom: data.postnom,
          message: data.message,
        },
      ]);
     // console.log("fffffffffff")
    });

    newSocket.on('disconnect', () => {
      console.log('Disconnected from server');
    });

    return () => {
      newSocket.disconnect();
    };
  }, []);

  const handleNotificationPress = (notification) => {
    // Logique pour afficher les détails de la notification
    console.log(notification);
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Notifications</Text>
      {notifications.map((notification) => (
        <TouchableOpacity
          key={notification.id}
          style={styles.notificationContainer}
          onPress={() => handleNotificationPress(notification)}
        >
          <Text style={styles.notificationTitle}>{`${notification.nom} ${notification.postnom}`}</Text>
          <Text style={styles.notificationMessage}>{notification.message}</Text>
        </TouchableOpacity>
      ))}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 20,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 20,
  },
  notificationContainer: {
    backgroundColor: '#f0f0f0',
    padding: 15,
    borderRadius: 8,
    marginVertical: 10,
    width: '100%',
  },
  notificationTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    marginBottom: 5,
  },
  notificationMessage: {
    fontSize: 14,
  },
});

export default NotificationsScreen;