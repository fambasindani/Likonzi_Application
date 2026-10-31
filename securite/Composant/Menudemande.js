import React from 'react';
import { StyleSheet, View, TouchableOpacity, Text } from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';

const Menudemande = () => {
  return (
    <View style={styles.container}>
      <View style={styles.optionsContainers}>
      
        <View style={styles.sendNotificationContainer}>
          <TouchableOpacity style={[styles.option, styles.sendNotificationOption]}>
            <Icon name="send" size={20} color="#fff" style={styles.optionIcon} />
            <Text style={styles.optionText}>Envoyer notification</Text>
          </TouchableOpacity>
        </View>
      </View>
      <View style={styles.optionsContainer}>
        <TouchableOpacity style={styles.option}>
          <Icon name="assignment" size={20} color="#333" style={styles.optionIcon} />
          <Text style={styles.optionText}>Demande</Text>
        </TouchableOpacity>
        <TouchableOpacity style={[styles.option, styles.notificationOption]}>
          <Icon name="check-circle" size={20} color="#fff" style={styles.optionIcon} />
          <Text style={styles.optionText}>Confirmation</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
  
   //marginTop: 30,
    flexDirection: 'column',
     alignItems: 'center',
    paddingHorizontal: 20,
    paddingBottom: 1,
   paddingTop: 10,
    backgroundColor: 'white',
  },
  optionsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    width: '100%',
    marginVertical: 8,
  },
  optionsContainers: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    width: '100%',
    paddingBottom: 20,
  },
  sendNotificationContainer: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    flex: 1,
  },
  option: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#fff',
    paddingVertical: 8,
    paddingHorizontal: 16,
    borderRadius: 20,
    elevation: 2,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.2,
    shadowRadius: 2,
  },
  notificationOption: {
    backgroundColor: '#ff6b6b',
  },
  sendNotificationOption: {
    backgroundColor: '#4CAF50',
  },
  logoutOption: {
    backgroundColor: '#E53935',
    marginRight: 16,
  },
  optionIcon: {
    marginRight: 8,
  },
  optionText: {
    color: '#333',
    fontSize: 16,
    fontWeight: 'bold',
  },
});

export default Menudemande;