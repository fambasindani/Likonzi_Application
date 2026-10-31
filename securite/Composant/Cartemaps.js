import React, { useState, useEffect } from 'react';
import { StyleSheet, View, PermissionsAndroid, Platform, Modal, TouchableOpacity, Text } from 'react-native';
import MapView, { Marker } from 'react-native-maps';
import * as Location from 'expo-location';

const Cartemaps = ({modalVisible,setModalVisible}) => {
  const [region, setRegion] = useState({
    latitude: -4.29843,
    longitude: 15.3121,
    latitudeDelta: 0.0922,
    longitudeDelta: 0.0421,
  });
 

  useEffect(() => {
    const requestLocationPermission = async () => {
        if(modalVisible){  
      if (Platform.OS === 'android') {

        try {

          const granted = await PermissionsAndroid.request(
            PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION,
            {
              title: 'Accès à la localisation',
              message: "Cette application a besoin d'accéder à votre localisation.",
              buttonNeutral: 'Me le demander plus tard',
              buttonNegative: 'Refuser',
              buttonPositive: 'Accepter',
            }
          );
          if (granted === PermissionsAndroid.RESULTS.GRANTED) {
            console.log('Autorisation accordée');
          } else {
            console.log('Autorisation refusée');
          }
        } catch (err) {
          console.warn(err);
        }
      } else {
        let { status } = await Location.requestForegroundPermissionsAsync();
        if (status !== 'granted') {
          console.log('Autorisation refusée');
          return;
        }
      }
    }

    };

    requestLocationPermission();
  }, []);

  return (
    <View style={styles.container}>
     {/* <TouchableOpacity
        style={styles.button}
        onPress={() => setModalVisible(true)}
      >
        <Text style={styles.buttonText}>Ouvrir la carte</Text>
      </TouchableOpacity>*/}

      <Modal
        visible={modalVisible}
        animationType="slide"
        transparent={false}
      >
        <View style={styles.modalContainer}>
          <MapView
            style={styles.map}
            initialRegion={region}
            mapType="standard"
          >
            <Marker
              coordinate={{
                latitude: -4.29843,
                longitude: 15.3121,
              }}
              title="Marker"
              description="Ma position"
            />
          </MapView>

          <TouchableOpacity
            style={styles.closeButton}
            onPress={() => setModalVisible(false)}
          >
            <Text style={styles.closeButtonText}>Fermer</Text>
          </TouchableOpacity>
        </View>
      </Modal>
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
  button: {
    backgroundColor: '#007AFF',
    padding: 15,
    borderRadius: 5,
  },
  buttonText: {
    color: '#fff',
    fontSize: 16,
  },
  modalContainer: {
    flex: 1,
    backgroundColor: '#fff',
  },
  map: {
    flex: 1,
  },
  closeButton: {
    backgroundColor: '#007AFF',
    padding: 10,
    borderRadius: 5,
    position: 'absolute',
    bottom: 20,
    right: 20,
  },
  closeButtonText: {
    color: '#fff',
    fontSize: 16,
  },
});

export default Cartemaps;