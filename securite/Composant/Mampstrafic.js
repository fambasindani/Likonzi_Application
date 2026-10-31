import React, { useState } from 'react';
import { StyleSheet, View, Text, TextInput, Button, Alert } from 'react-native';
import MapView, { Marker, PROVIDER_GOOGLE } from 'react-native-maps';
import Icon from 'react-native-vector-icons/Ionicons';
import axios from 'axios';

const API_KEY = 'VOTRE_CLE_API'; // Remplacez par votre clé API Google

const TrafficMaps = () => {
    const [markerCoordinate, setMarkerCoordinate] = useState({
        latitude: -4.4419,
        longitude: 15.3129,
    });
    const [locationInput, setLocationInput] = useState('');

    const handleSearch = async () => {
        try {
            const response = await axios.get(`https://maps.googleapis.com/maps/api/geocode/json`, {
                params: {
                    address: locationInput,
                    key: API_KEY,
                },
            });

            if (response.data.results.length > 0) {
                const { lat, lng } = response.data.results[0].geometry.location;
                setMarkerCoordinate({ latitude: lat, longitude: lng });
            } else {
                Alert.alert("Erreur", "Aucun résultat trouvé pour cette recherche.");
            }
        } catch (error) {
            console.error("Erreur lors de la recherche : ", error);
            Alert.alert("Erreur", "Une erreur est survenue lors de la recherche.");
        }
    };

    return (
        <View style={styles.container}>
            <View style={styles.searchContainer}>
                <View style={styles.inputContainer}>
                    <Icon name="search" size={20} color="gray" style={styles.icon} />
                    <TextInput
                        style={styles.input}
                        placeholder="Entrez le nom du lieu"
                        value={locationInput}
                        onChangeText={setLocationInput}
                    />
                </View>
                <Button title="Rechercher" onPress={handleSearch} />
            </View>
            <MapView
                provider={PROVIDER_GOOGLE}
                style={styles.map}
                region={{
                    latitude: markerCoordinate.latitude,
                    longitude: markerCoordinate.longitude,
                    latitudeDelta: 0.1,
                    longitudeDelta: 0.1,
                }}
                showsTraffic={true} // Active la couche de trafic
            >
                <Marker coordinate={markerCoordinate}>
                    <View style={styles.markerContainer}>
                        <Text style={styles.markerText}>Pierre</Text>
                    </View>
                </Marker>
            </MapView>
        </View>
    );
};

const styles = StyleSheet.create({
    container: {
        flex: 1,
    },
    searchContainer: {
        marginTop: 30,
        padding: 10,
        backgroundColor: 'white',
        elevation: 2,
    },
    inputContainer: {
        flexDirection: 'row',
        alignItems: 'center',
        borderColor: 'gray',
        borderWidth: 1,
        borderRadius: 5,
        padding: 5,
        marginBottom: 10,
    },
    icon: {
        marginRight: 10,
    },
    input: {
        flex: 1,
        height: 40,
    },
    map: {
        flex: 1,
    },
    markerContainer: {
        backgroundColor: 'white',
        padding: 5,
        borderRadius: 5,
        borderWidth: 1,
        borderColor: 'black',
    },
    markerText: {
        fontWeight: 'bold',
    },
});

export default TrafficMaps;