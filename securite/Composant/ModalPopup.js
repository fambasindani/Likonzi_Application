import React, { useState } from 'react';
import { Modal, View, Text, StyleSheet, Dimensions, Image, TouchableWithoutFeedback } from 'react-native';

const ModalPopup = ({email, phone,nom, prenom, toggleModal,modalVisible,setModalVisible}) => {

  
  const user = {
    photo: require('../assets/user.png'), // Utiliser require() pour charger l'image locale
    firstName: 'John',
    lastName: 'Doe',
    gender: 'Male',
    address: '123 Main St, Anytown USA',
    phone: {phone},
    email: {email},
  };



  return (
    <View style={styles.container}>
      <Modal
        animationType="fade"
        transparent={true}
        visible={modalVisible}
        onRequestClose={toggleModal}
      >
        <View style={styles.modalContainer}>
          <View style={styles.modalContent}>
            <Image source={user.photo} style={styles.userPhoto} />
            <View style={styles.userDetails}>
              <Text style={styles.userName}>{prenom} {nom}  </Text>

              {/*       <Text style={styles.userInfo}>{user.address}</Text> */}
              <Text style={styles.userInfo}>{phone}</Text>
              <Text style={styles.userInfo}>{email}</Text>
            </View>
          </View>
          <TouchableWithoutFeedback onPress={toggleModal}>
            <View style={styles.modalBackdrop} />
          </TouchableWithoutFeedback>
        </View>
      </Modal>

    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    //  flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
  },
  modalContent: {
    backgroundColor: 'white',
    padding: 20,
    width: Dimensions.get('window').width * 0.8,
    height: 200, // Définir une hauteur de 200 pixels
    borderRadius: 10,
    flexDirection: 'row',
    alignItems: 'center',
  },
  userPhoto: {
    width: 80,
    height: 80,
    borderRadius: 40,
    marginRight: 20,
  },
  userDetails: {
    flex: 1,
  },
  userName: {
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 5,
  },
  userInfo: {
    fontSize: 16,
    marginBottom: 5,
  },
 
  modalBackdrop: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
  },
});

export default ModalPopup;