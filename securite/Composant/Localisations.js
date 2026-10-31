import React, { useState, useEffect } from 'react';
import { View, Text, Alert } from 'react-native';
import * as Location from 'expo-location';
import axios from 'axios';
import AsyncStorage from '@react-native-async-storage/async-storage';
import ApiUrl from './ApiUrl';

const Localisations = () => {
  const [location, setLocation] = useState(null);
  const [monid, setMonid] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const getMonid = async () => {
      try {
        const storedMonid = await AsyncStorage.getItem('monid');
        if (storedMonid !== null) {
          setMonid(storedMonid);
        } else {
          console.error('monid is null, unable to update location');
        }
        setLoading(false);
      } catch (error) {
        console.error(error);
        setLoading(false);
      }
    };

    const getLocation = async () => {
      try {
        const { status } = await Location.requestForegroundPermissionsAsync();
        if (status !== 'granted') {
          console.error('Permission to access location was denied');
          setLoading(false);
          return;
        }

        const location = await Location.getCurrentPositionAsync({});
        setLocation(location);
        if (monid !== null) {
          updateLocation(location.coords.latitude, location.coords.longitude);
        } else {
          console.error('monid is null, unable to update location');
        }
        setLoading(false);
      } catch (error) {
        console.error(error);
        setLoading(false);
      }
    };

    const interval = setInterval(getLocation, 5000); // Mettre à jour toutes les 5 secondes
    getMonid();
    return () => clearInterval(interval);
  }, []);

  const updateLocation = async (latitude, longitude) => {
    try {
      if (monid !== null) {
        const formData = new FormData();
        formData.append('iduser', monid);
        formData.append('latitude', latitude);
        formData.append('longitude', longitude);

        const url = ApiUrl({ endpoint: 'createpublication' });
        const res = await axios.post(url, formData, {
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        });
        console.log(res.data);
      } else {
        console.error('monid is null, unable to update location');
      }
    } catch (error) {
      console.error(error);
    }
  };

  return (
    <>
      {loading ? (
        <View>
          <Text>Chargement en cours...</Text>
        </View>
      ) : monid === null ? (
        <View>
          <Text>Impossible de mettre à jour la localisation.</Text>
        </View>
      ) : (
        // Rendu normal du composant
        <></>
      )}
    </>
  );
};

export default Localisations;