import React from 'react';
import { TouchableOpacity, Text, StyleSheet, View } from 'react-native';
import COLORS from '../Couleurs/COLORS';

const Boutons = ({Actioninscription, Actionpassword, title, onPress = () => { } }) => {
    //<> </>

    return (
        <View style={styles.container}>
            <TouchableOpacity
                onPress={onPress}
                style={{
                    // width:"100%",
                    backgroundColor: COLORS.vert,
                    justifyContent: 'center',
                    alignItems: 'center',
                    marginTop: 20,
                    borderRadius: 10,
                    paddingVertical: 12,

                }}


            ><Text
                style={{
                    color: COLORS.white,
                    fontWeight: 'bold',
                    fontSize: 20,


                }}


            >{title}</Text></TouchableOpacity>



            <View style={styles.contenu} >

                <Text style={styles.texts} onPress={Actioninscription}>
                    Inscription
                </Text>
                <Text style={styles.texts} onPress={Actionpassword}>
                    Password oublié
                </Text>
            </View>


        </View>
    );
};


const styles = StyleSheet.create({
    container: {
        width: '90%'
        // flex: 1,
        // justifyContent: 'center',
        //  alignItems: 'center',
        //  backgroundColor: '#f5f5f5',
    },
    texts: {

        color: COLORS.blue,
        fontWeight: 'bold',
        fontSize: 18,

    },

    contenu: {


        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        marginVertical: 10,


    },


})

export default Boutons;