import React, { useState } from 'react';
import { View, Text, TouchableOpacity, Modal, StyleSheet, TouchableWithoutFeedback } from 'react-native';


const Message = ({ handleCloseModal , text, showSuccessModal, setShowSuccessModal}) => {

  
const SuccessModal = ({ visible, onClose}) => {
  return (
    <Modal visible={visible} transparent onRequestClose={onClose}>
      <TouchableWithoutFeedback onPress={onClose}>
        <View style={styles.modalContainer}>
          <View style={[styles.modalContent, styles.roundedCorners]}>
            <Text style={styles.message1}>Notification</Text>
            <Text style={styles.message}>{text}</Text>
          </View>
        </View>
      </TouchableWithoutFeedback>
    </Modal>
  );
};


  return (
    <View style={styles.container}>
   
      <SuccessModal visible={showSuccessModal} onClose={handleCloseModal} />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#F5FCFF',
  },
  modalContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
  },
  modalContent: {
    backgroundColor: 'white',
    paddingVertical: 20,
    paddingHorizontal: 20,
    alignItems: 'center',
    width: '80%',
  },
  roundedCorners: {
    borderRadius: 10,
  },
  message: {
    fontSize: 18,
    textAlign: 'center',
  },
  message1: {
    fontSize: 20,
    fontWeight: 'bold',
    marginBottom: 10,
  },
  button: {
    backgroundColor: '#007AFF',
    paddingVertical: 10,
    paddingHorizontal: 20,
  },
  buttonText: {
    color: 'white',
    fontSize: 16,
  },
});

export default Message;