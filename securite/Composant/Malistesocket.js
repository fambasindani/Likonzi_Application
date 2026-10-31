import React, { useState, useEffect } from 'react';
import { View, Text, Button, FlatList, StyleSheet } from 'react-native';
import io from 'socket.io-client';
import * as Notifications from 'expo-notifications';

const Malistesocket = () => {
  const [socketConnection, setSocketConnection] = useState(null);
  const [receivedData, setReceivedData] = useState(null);

  useEffect(() => {
    // Créer une instance de socket.io-client
    const socket = io('http://192.168.68.103:1200', {
      transports: ['websocket'],
    });

    // Gérer la connexion
    socket.on('connect', () => {
      console.log('Connected to server');
      setSocketConnection(socket);
    });

    // Gérer la réception des données
    socket.on('v', (data) => {
      console.log('Received data:', data);
      setReceivedData(data);
      sendNotification(data);
      console.log(data);
    });

    // Gérer les erreurs
    socket.on('error', (error) => {
      console.error('Socket.IO error:', error);
    });

    // Nettoyer la connexion WebSocket lors du démontage du composant
    return () => {
      socket.disconnect();
    };
  }, []);

  // Envoyer une notification
  const sendNotification = async (data) => {
    // Récupérer l'ID de l'utilisateur connecté
    const currentUserId = 16; // Remplacez par la vraie valeur de l'ID de l'utilisateur connecté

    // Parcourir les données reçues
    for (const user of data.data) {
      // Vérifier si l'ID de l'utilisateur est différent de l'ID de l'utilisateur connecté
      if (user.id === currentUserId) {
        // Envoyer la notification
        await Notifications.scheduleNotificationAsync({
          content: {
            title: 'Notification',
            body: `${user.nom} est en danger`,
            android: {
              channelId: 'channel-id',
              sound: true,
              color: '#FF0000',
              icon: 'adaptive-icon'
            }
          },
          trigger: { seconds: 1 }
        });
      }
    }
  };

  // Envoyer des données au serveur
  const sendMessage = () => {
    if (socketConnection) {
      socketConnection.emit('message', { data: 'Hello, server!' });
    }
  };

  // Afficher le contenu de data dans une FlatList
  const renderItem = ({ item }) => (
    <View style={styles.itemContainer}>
      <Text style={styles.itemText}>Nom: {item.nom}</Text>
      <Text style={styles.itemText}>ID: {item.id}</Text>
    </View>
  );

  return (
  <View style={styles.container}>
      {/* <Text style={styles.title}>WebSocket Component</Text>
      <Button title="Send Message" onPress={sendMessage} style={styles.button} />*/}

      {receivedData && (
        <FlatList
          data={receivedData.data}
          keyExtractor={(item) => item.id.toString()}
          renderItem={renderItem}
          style={styles.flatList}
        />
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#F5FCFF',
  },
  title: {
    fontSize: 20,
    fontWeight: 'bold',
    marginBottom: 20,
  },
  button: {
    marginVertical: 10,
  },
  flatList: {
    width: '100%',
  },
  itemContainer: {
    padding: 10,
    borderWidth: 1,
    borderColor: '#ccc',
    marginVertical: 5,
  },
  itemText: {
    fontSize: 16,
  },
});

export default Malistesocket;