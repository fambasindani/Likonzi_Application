import React, { useState } from 'react';
import { View, TextInput, TouchableOpacity, StyleSheet, Text, Alert } from 'react-native';
import Icon from 'react-native-vector-icons/FontAwesome';
import COLORS from '../Couleurs/COLORS';

const PasswordInput = ({password,setPassword, label}) => {

  const [showPassword, setShowPassword] = useState(false);

  const handleValidation = () => {
    if (password.trim() === '') {
      Alert.alert('Message', 'Veuillez saisir un mot de passe.');
    } else {
      console.log('Mot de passe saisi :', password);
    }
  };

  const togglePasswordVisibility = () => {
    setShowPassword(!showPassword);
  };

  return (
    <View style={styles.container}>
         <Text style={styles.label}> {label}</Text>
      <View style={styles.inputContainer}>
   
        <TouchableOpacity style={styles.lockIcon}>
          <Icon name="lock" size={20} color="#888" />
        </TouchableOpacity>
        <TextInput
          style={[styles.input, { paddingLeft: 20 }]}
          placeholder="Votre mot de passe"
          secureTextEntry={!showPassword}
          value={password}
          onChangeText={setPassword}
        />
        <TouchableOpacity onPress={togglePasswordVisibility} style={styles.passwordToggleIcon}>
          <Icon name={showPassword ? 'eye-slash' : 'eye'} size={20} color="#888" />
        </TouchableOpacity>
      </View>
     
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    width:'100%',

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
    marginHorizontal: 20,
  },
  input: {
    flex: 1,
    fontSize: 16,
  },
  passwordToggleIcon: {
    position: 'absolute',
    right: 12,
  },
  lockIcon: {
    position: 'absolute',
    left: 12,
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
    textAlign:'auto'

  },
});

export default PasswordInput;