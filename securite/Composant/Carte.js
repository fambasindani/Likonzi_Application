import React, { useState, useEffect } from 'react';
import { StyleSheet, View, PermissionsAndroid, Platform } from 'react-native';
import MapView, { Marker } from 'react-native-maps';
import * as Location from 'expo-location';

const Carte = () => {
  const [region, setRegion] = useState({
    latitude: -4.29843,
    longitude: 15.3121,
    latitudeDelta: 0.0922,
    longitudeDelta: 0.0421,
  });

  useEffect(() => {
    const requestLocationPermission = async () => {
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
        // Gestion de la demande d'autorisation sur iOS
        let { status } = await Location.requestForegroundPermissionsAsync();
        if (status !== 'granted') {
          console.log('Autorisation refusée');
          return;
        }
      }
    };

    requestLocationPermission();
  }, []);

  return (
    <View style={styles.container}>
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
  map: {
    width: '100%',
    height: '100%',
  },
});

export default Carte;