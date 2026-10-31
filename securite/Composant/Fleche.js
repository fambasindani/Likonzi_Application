import React from 'react';
import { StyleSheet, View, TouchableOpacity, Text } from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';

const Fleche = ({ onPress, titre }) => {
  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <TouchableOpacity style={styles.backButton} onPress={onPress}>
          <Icon name="arrow-back" size={24} color="#333" />
        </TouchableOpacity>
        <Text style={styles.title}>{titre}</Text>
      </View>
     
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
  // flex: 1,
    backgroundColor: '#fff',
    marginTop:30,
    marginBottom:7,
   // paddingBottom:10,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 16,
    paddingHorizontal: 20,
    backgroundColor: 'white',
  },
  backButton: {
    position: 'absolute',
    left: 16,
    top: 16,
  },
  title: {
    textAlign:'center',
    fontSize: 18,
    fontWeight: 'bold',
    marginLeft: 40, // Ajouter un espacement entre le bouton et le titre
  },

});

export default Fleche;