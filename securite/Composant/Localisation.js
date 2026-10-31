import React, { useState, useEffect } from 'react';
import { View, Text, Alert } from 'react-native';
import * as Location from 'expo-location';
import axios from 'axios';
import AsyncStorage from '@react-native-async-storage/async-storage';
import ApiUrl from './ApiUrl';

const Localisation = () => {
  const [location, setLocation] = useState(null);

  useEffect(() => {
    const getLocation = async () => {
      try {
        const { status } = await Location.requestForegroundPermissionsAsync();
        if (status !== 'granted') {
          console.error('Permission to access location was denied');
          return;
        }
        const id = await AsyncStorage.getItem('key');
        const location = await Location.getCurrentPositionAsync({});
        setLocation(location);
        updateLocation(location.coords.latitude, location.coords.longitude,id );
      } catch (error) {
        console.error(error);
      }
    };

    const interval = setInterval(getLocation, 5000); // Mettre à jour toutes les 5 secondes
    return () => clearInterval(interval);
  }, []);



  const updateLocation = async (latitude, longitude,id) => {
  
  
    try {
      const formData = new FormData();
      formData.append('iduser', id);
      formData.append('latitude', latitude);
      formData.append('longitude', longitude);
      const url = ApiUrl({ endpoint: 'createpublication' });
      

    

            const res = await axios.post(url, formData, {
                headers: {
                  'Content-Type': 'multipart/form-data',
                },
              });

              console.log(res.data)
              console.log(id)
         //}


             


   
  

   
    } catch (error) {
      console.error(error);
    }
  };


  return (
    <View>
      <Text></Text>
    </View>
  );
};

export default Localisation;