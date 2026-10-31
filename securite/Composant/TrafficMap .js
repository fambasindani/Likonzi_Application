import React, { useEffect, useState } from 'react';
import { StyleSheet, View, Text, ActivityIndicator, Alert } from 'react-native';
import MapView, { PROVIDER_GOOGLE, Marker, Polyline } from 'react-native-maps';
import axios from 'axios';

const API_KEY = 'VOTRE_CLE_API'; // Remplacez par votre clé API

const TrafficMap = () => {
    const [routeInfo, setRouteInfo] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [trafficRoutes, setTrafficRoutes] = useState([]); // État pour stocker les routes

    const fetchTrafficData = async () => {
        const origin = '-4.4419,15.3129'; // Coordonnées de Kinshasa
        const destination = '-4.4410,15.3120'; // Remplacez par votre destination

        try {
            const response = await axios.get(`https://maps.googleapis.com/maps/api/directions/json`, {
                params: {
                    origin,
                    destination,
                    key: API_KEY,
                    alternatives: true, // Demander des itinéraires alternatifs
                    traffic_model: 'best_guess',
                    departure_time: 'now',
                }
            });

            if (response.data.routes && response.data.routes.length > 0) {
                setTrafficRoutes(response.data.routes); // Stocker toutes les routes
                const leg = response.data.routes[0].legs[0];
                setRouteInfo(leg);
            } else {
                setError("Aucune route trouvée.");
            }
        } catch (error) {
            console.error("Erreur : ", error);
            setError("Erreur lors de la récupération des données.");
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {

       // Rouge : Trafic très lent ou embouteillage.
//Orange : Trafic modéré, circulation plus lente que la normale.
//Jaune : Trafic léger, circulation fluide mais plus lente que d'habitude.
//Vert : Circulation normale, pas de problèmes de trafic.
        fetchTrafficData();
    }, []);

    return (
        <View style={styles.container}>
            <MapView
                provider={PROVIDER_GOOGLE}
                style={styles.map}
                region={{
                    latitude: -4.4419,
                    longitude: 15.3129,
                    latitudeDelta: 0.1,
                    longitudeDelta: 0.1,
                }}
                showsTraffic={true} // Active la couche de trafic
            >
                {trafficRoutes.map((route, index) => {
                    const coordinates = route.legs[0].steps.map(step => ({
                        latitude: step.end_location.lat,
                        longitude: step.end_location.lng,
                    }));

                    return (
                        <Polyline
                            key={index}
                            coordinates={coordinates}
                            strokeColor={index === 0 ? 'blue' : 'green'} // Itinéraire principal en bleu, alternatifs en vert
                            strokeWidth={5}
                        />
                    );
                })}
            </MapView>
            {loading ? (
                <ActivityIndicator size="large" color="#0000ff" style={styles.loading} />
            ) : error ? (
                <View style={styles.info}>
                    <Text>{error}</Text>
                </View>
            ) : (
                routeInfo && (
                    <View style={styles.info}>
                        <Text>Durée estimée : {routeInfo.duration.text}</Text>
                        <Text>Distance : {routeInfo.distance.text}</Text>
                    </View>
                )
            )}
        </View>
    );
};

const styles = StyleSheet.create({
    container: {
        flex: 1,
    },
    map: {
        flex: 1,
    },
    loading: {
        position: 'absolute',
        top: '50%',
        left: '50%',
        marginLeft: -20,
        marginTop: -20,
    },
    info: {
        position: 'absolute',
        bottom: 20,
        left: 10,
        backgroundColor: 'rgba(255, 255, 255, 0.8)',
        padding: 10,
        borderRadius: 5,
    },
});

export default TrafficMap;