import React from 'react';
import { View, StyleSheet, useWindowDimensions, Text, ActivityIndicator } from 'react-native';
import COLORS from '../Couleurs/COLORS';

const Loading = ({ visible = true }) => {
    const { height, width } = useWindowDimensions();
    return (
        visible && (
            <View style={[style.contaire, { height, width }]}>
                <View style={[style.loader]}>
                    <ActivityIndicator size="large" color={COLORS.blue} />
                    <Text style={{ marginLeft: 10, fontSize: 16 }}>Loading...</Text>
                </View>
            </View>
        )
    );
};
const style = StyleSheet.create({
    contaire: {
        position: 'absolute',
        zIndex: 10,
        backgroundColor: 'rgba(0, 0, 0,0, 0.5)', // Blanc avec 10% d'opacité
        justifyContent: 'center',
        alignItems: 'center',
        width: '100%',
        height: '100%',

      
    
    },
    loader: {
        height: 70,
        backgroundColor: COLORS.beige,
        marginHorizontal: 50,
        flexDirection: 'row',
        paddingHorizontal: 20,
        alignItems: 'center',
        borderRadius: 5
    },
    loaderImage: {
        width: 20,
        height: 20,
        marginRight: 10,
    },
});
export default Loading;