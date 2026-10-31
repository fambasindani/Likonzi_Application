import React, { useEffect, useState } from 'react';
import { StyleSheet, View, SafeAreaView, TouchableOpacity, Text, TextInput } from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import Listeamis from './Listeamis';
import COLORS from '../Couleurs/COLORS';
import ApiUrl from './ApiUrl';
import axios from 'axios';

const MonMenu = ({ navigation }) => {

  const [userData, setUserData] = useState([]);
  

  const data= [
    {
       "id":1,
      "nom": "John Doe",
      "prenom": "Dupont",
   
    },
    {
      "id":2,
      "nom": "Jane Smith",
      "prenom": "Lefebvre",
   
    },
    {
      "id":3,
      "nom": "Bob Johnson",
      "prenom": "Martin",
   
    },
    {
      "id":4,
      "nom": "Alice Williams",
      "prenom": "Dubois",
     
    },
    {
      "id":5,
      "nom": "Tom Davis",
      "prenom": "Durand",
    
    }
  ]

  const fetchUserData = async () => {
    try {
      const url = ApiUrl({ endpoint: 'getuser' });
      const response = await axios.get(url);
      const monData = response.data;
      setUserData(monData);
      console.log(response.data[0].nom)
    } catch (error) {
      console.error('Error fetching user data:', error);
    }
  };


  useEffect(() => {
   
    fetchUserData();
  }, []);


















  const [searchText, setSearchText] = useState('');

  const Actionami = () => {
    navigation.navigate('Ts');
  };

  const Actionlogin = () => {
    navigation.navigate('Loginscreen');
  };

  const handleSearch = (text) => {
    setSearchText(text);
  };
   
  //const filteredData = userData.filter((item) =>
  // item.nom.toLowerCase().includes(searchText.toLowerCase())
 //);


 const filteredData = userData.filter((item) =>
  item.nom.toLowerCase().includes(searchText.toLowerCase()) ||
  item.prenom.toLowerCase().includes(searchText.toLowerCase())
);

  const clearSearch = () => {
    setSearchText('');
  };



  return (
    <SafeAreaView style={{ backgroundColor: COLORS.blanccasse, flex: 1 }}>
      <View style={styles.container}>
        <View style={styles.optionsContainers}>
          <TouchableOpacity style={[styles.option, styles.logoutOption]} onPress={Actionlogin}>
            <Icon name="logout" size={20} color="#fff" style={styles.optionIcon} onPress={Actionlogin} />
          </TouchableOpacity>
          <View style={styles.sendNotificationContainer}>
            <TouchableOpacity style={[styles.option, styles.sendNotificationOption]}>
              <Icon name="send" size={20} color="#fff" style={styles.optionIcon} />
              <Text style={styles.optionText}>Envoyer notification</Text>
            </TouchableOpacity>
          </View>
        </View>

        
        <View style={styles.optionsContainer}>
          <TouchableOpacity style={styles.option} onPress={Actionami}>
            <Icon name="people" size={20} color="#333" style={styles.optionIcon} />
            <Text style={styles.optionText}>Amis</Text>
          </TouchableOpacity>
          <TouchableOpacity style={[styles.option, styles.notificationOption]}>
            <Icon name="notifications" size={20} color="#fff" style={styles.optionIcon} />
            <Text style={styles.optionText}>Notifications</Text>
          </TouchableOpacity>
        </View>
        
        <View style={styles.searchContainers}>
          <View style={styles.searchContainer}>
            <TextInput
              style={styles.searchInput}
              placeholder="Rechercher..."
              placeholderTextColor="#999"
              value={searchText}
              onChangeText={handleSearch}
            />
            {searchText !== '' && (
              <TouchableOpacity onPress={clearSearch}>
                <Icon name="close" size={20} color="#999" style={styles.searchIcon} />
              </TouchableOpacity>
            )}
            {searchText === '' && (
              <Icon name="search" size={20} color="#999" style={styles.searchIcon} />
            )}
          </View>
        </View>
      </View>

      <Listeamis mydata={filteredData}  />
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  searchContainers: {
    flexDirection: 'column',
    width: '100%',
    marginVertical: 8,
  },
  searchContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.blanccasse,
    borderRadius: 8,
    paddingHorizontal: 12,
    marginVertical: 8,
  },
  searchInput: {
    flex: 1,
    fontSize: 16,
    color: '#333',
    paddingVertical: 8,
  },
  searchIcon: {
    marginLeft: 8,
  },
  container: {
    marginTop: 30,
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

export default MonMenu;