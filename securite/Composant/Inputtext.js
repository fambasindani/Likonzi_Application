import React, { useState } from 'react';
import { View, TextInput, TouchableOpacity, StyleSheet, Text, Alert } from 'react-native';
import Icon from 'react-native-vector-icons/FontAwesome';
import COLORS from '../Couleurs/COLORS';

const Input = ({name, setname, icons, placeholder, label, type}) => {
 
  return (

    //  <TouchableOpacity style={styles.validationButton} onPress={handleValidation}>
    //<Text style={styles.validationButtonText}>Valider</Text>
   // </TouchableOpacity>


   <View  style={styles.container}>

  <Text style={styles.label}>{label}</Text>
      <View style={styles.inputContainer}>
       
        <Icon name={icons} size={17} color="#888" style={styles.inputIcon} />
        <TextInput
          style={styles.input}
          placeholder={placeholder}
          keyboardType={type}
          value={name}
          onChangeText={setname}
        />
      </View>

      </View>
        
    




    
  );
};

const styles = StyleSheet.create({
  container: {
    width:'100%'
   // flex: 1,
  // justifyContent: 'center',
 //  alignItems: 'center',
  //  backgroundColor: '#f5f5f5',
  },
  inputContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#fff',
    borderWidth: 1,
    borderColor: '#ccc',
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
    marginBottom: 16,
    marginHorizontal:20,
  },
  inputIcon: {
    marginRight: 8,
  },
  input: {
    flex: 1,
    fontSize: 16,
  },
  validationButton: {
    backgroundColor: '#4CAF50',
    paddingVertical: 12,
    paddingHorizontal: 130,
    borderRadius: 8,
  },
  validationButtonText: {
    color: 'white',
    fontSize: 16,
    fontWeight: 'bold',
  },
  label:{
    color: COLORS.black,
    marginLeft:24,
    marginBottom:5,
    fontSize:16,

  },
});

export default Input;