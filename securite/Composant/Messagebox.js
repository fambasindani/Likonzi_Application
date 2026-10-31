import React, { useState } from 'react';
import { View, Text, TouchableOpacity, Modal, StyleSheet } from 'react-native';

const ConfirmationModal = ({ visible, message, onConfirm, onCancel}) => {
  return (
    <Modal visible={visible} transparent>
      <View style={styles.modalContainer}>
        <View style={[styles.modalContent, styles.roundedCorners]}>
          <Text style={styles.message}>{message}</Text>
          <View style={styles.buttonContainer}>
            <TouchableOpacity
              style={[styles.button, styles.roundedCorners]}
              onPress={onConfirm}
            >
              <Text style={styles.buttonText}>Oui</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.button, styles.roundedCorners]}
              onPress={onCancel}
            >
              <Text style={styles.buttonText}>Non</Text>
            </TouchableOpacity>
          </View>
        </View>
      </View>
    </Modal>
  );
};

const Messagebox = ({modalVisible, setModalVisible, handleConfirm,handleCancel, message}) => {



  return (
    <View style={styles.container}>
    
      <ConfirmationModal
        visible={modalVisible}
        message={message}
        onConfirm={handleConfirm}
      
        onCancel={handleCancel}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
   // flex: 1,
   // justifyContent: 'center',
  //  alignItems: 'center',
  },
  modalContainer: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.2)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalContent: {
    backgroundColor: 'white',
    padding: 20,
    width: '80%',
  },
  roundedCorners: {
    borderRadius: 8,
  },
  message: {
    fontSize: 18,
    marginBottom: 20,
  },
  buttonContainer: {
    flexDirection: 'row',
    justifyContent: 'space-around',
  },
  button: {
    backgroundColor: '#007AFF',
    paddingVertical: 12,
    paddingHorizontal: 24,
  },
  buttonText: {
    color: 'white',
    fontSize: 16,
  },
});

export default Messagebox;