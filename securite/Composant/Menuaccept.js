import React, { useEffect, useState } from 'react';
import { FlatList, StyleSheet, Text, TextInput, TouchableOpacity, View, Alert, Image, Platform } from 'react-native';
import COLORS from '../Couleurs/COLORS';

import Icon from 'react-native-vector-icons/FontAwesome';
import Listeamis from './Listeamis';
import axios from 'axios';
import ApiUrl from './ApiUrl';

import Listenotification from './Listenotification';

import Listealerte from './Listealerte';
import { useNavigation } from '@react-navigation/native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import Messagebox from './Messagebox';




const Menuaccept = ({ navigation }) => {
  const [selectedIndex, setSelectedIndex] = useState(-1);
  const [selectedText, setSelectedText] = useState('');

  const [verficationami, setverficationami] = useState(true);
  const [verficationnotic, setverficationnotic] = useState(false);
  const [verficationalert, setverficationalert] = useState(false);
  const [couleurb, setcouleurb] = useState(false);
    const [couleurdemande, setcouleurdemande] = useState(false);
  const [userData, setUserData] = useState([]);
  const [currentpage, setcurrentpage] = useState(0);
  const [Loading, SetLoading] = useState(false);
  const [userid, setuserid] = useState(null);

  const [searchText, setSearchText] = useState('');

  const [showSuccessModal, setShowSuccessModal] = useState(false);
  const [message, Setmessage] = useState('')
  const [modalVisible, SetmodalVisible] = useState(false)
  const [selected, Setselected] = useState(null)
  const [selecteddelete, Setselecteddelete] = useState(null)
  const [verifierdelete, Setverifierdelete] = useState(false)
  const [verifeinsertion, Setverifeinsertion] = useState(false)

  useEffect(() => {
    //setuserid()
   // fetchUserData();
  }, []);
  
 
 

  const fetchUserData = async () => {
   
   var userids = await AsyncStorage.getItem('key');

   const nextpage=currentpage+1;

    SetLoading(true);
    try {

      const urls = ApiUrl({ endpoint: `getacceptation/${userids }` });

      const url = `${urls}?page=${nextpage}&per_page=10`;
      const response = await axios.get(url);
      const newData = response.data.data;
      console.log(newData)
  
        setcurrentpage(nextpage);
        setUserData((prevData) => prevData.concat(newData));
        SetLoading(false);
      
    


      
    } catch (error) {
      console.error('Error fetching user data:', error);
    } finally {
      SetLoading(false);
    }
  };



 
   

  

  const handleSearch = (text) => {
    setSearchText(text);
  };

  const filteredData = userData.filter((item) =>
   item.nom.toLowerCase().includes(searchText.toLowerCase()) ||
    item.prenom.toLowerCase().includes(searchText.toLowerCase())
  );

  const clearSearch = () => {
    setSearchText('');
  };


 


  const handleCloseModal = () => {
    setShowSuccessModal(false);
  };


  const handleConfirms = async () => {
   if(verifeinsertion){
    const item=selected
    await createaccepter(item) 
   }
   else if(verifierdelete){
  const itemdelete=selecteddelete
  // Alert.alert(itemdelete.idc.toString())
    actionsupprimer(itemdelete)

   }
 
  
  }


  const handleConfirm = async (item) => {
  
    Setverifierdelete(false)
    Setverifeinsertion(true)
    setShowSuccessModal(true);
    SetmodalVisible(true)
    Setselected(item)
    Setmessage(`Voulez-vous envoyer une demande à ${item.nom} ?`);


  }

  const handleCancel = async () => {
 
    SetmodalVisible(false)
 
  
  
  }

  //delete_accepter


  const createaccepter = async (item) => {
    setcouleurdemande(true)
    try {
      const url = ApiUrl({ endpoint: 'create_accepter' });
   
      const formData = new FormData();
      formData.append('id', item.idc);
    
      const res = await axios.put(url, formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      });

     


      setverficationami(true)
      console.log(res.data+"  "+item.nom);

   
        navigation.replace('Menuaccept');
      
      
     
    } catch (error) {
      console.error(error);
    }
  };

  const data = ['Amis', 'Notifications', 'Voir Alert', 'Envoyer Alerts', 'Déconnecter'];




  const renderItem = ({ item, index }) => (
    <TouchableOpacity
      style={[
        styles.item,
     

        (item === 'Notifications') ? styles.selectedItem : null,
       //   (item === 'Notifications' && couleurdemande) ? styles.selectedItem : null,
       // selectedIndex === index && !couleurb ? styles.selectedItem : null

      ]}
      onPress={() => {
        setSelectedIndex(index);
        setSelectedText(item);
        handleItemClick(item);
        setcouleurb(false)
      }}

    >
      <Text style={[
        styles.itemText,
        selectedIndex === index ? COLORS.white : COLORS.beige
        // (selectedIndex === index && item === 'Amis') ? COLORS.red : COLORS.blue
      ]}>
        {item}
      </Text>
    </TouchableOpacity>
  );



  const handleItemClick = (item) => {
    if (item === "Déconnecter") {
      navigation.navigate('Loginscreen');

    }

    if (item === "Amis") {
        navigation.navigate("Menus")
     // Alert.alert('Message', 'amis')
    }
    if (item === "Notifications") {
      fetchUserData();
      setverficationami(false)
      setverficationnotic(true)
      setverficationalert(false)
     // Alert.alert('Message', 'Notifications')

    }

    if (item === "Voir Alert") {
      


    }
    if (item === "Envoyer Alerts") {



    }




  };

  const handdelete = async(item) => {
    Setverifierdelete(true)
    Setverifeinsertion(false)
    setShowSuccessModal(true);
    SetmodalVisible(true)
    Setselecteddelete(item)
    Setmessage(`Voulez-vous supprimer la demande à ${item.nom} ?`);

  }




  const actionsupprimer = async (item) => {
    const url = ApiUrl({ endpoint: 'delete_accepter' });

    try {
      await axios.delete(`${url}/${item.idc.toString()}`);
      navigation.replace('Menuaccept');
    } catch (error) {
      console.error(error);
    }
  };


  
  return (
    <View style={styles.complet}>
 
     
      <View style={styles.headerContainer}>
        <Text style={styles.headerText}>Securité</Text>
      </View>


      <View style={styles.container}>


        <FlatList
          data={data}
          renderItem={renderItem}
          keyExtractor={(item, index) => index.toString()}
          horizontal
          snapToAlignment="center"
          decelerationRate="fast"
          showsHorizontalScrollIndicator={false}
        />
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

     
          <Listenotification handdelete={handdelete} mydata={filteredData}  fetchUserData={fetchUserData}   SetLoading={SetLoading} Loading={Loading}  handleConfirm={handleConfirm}   />
          <Messagebox   message={message} handleConfirm={handleConfirms} handleCancel={handleCancel}  modalVisible={modalVisible}  handleCloseModal={handleCloseModal}  showSuccessModal={showSuccessModal} setShowSuccessModal={setShowSuccessModal}  />

      

     
    

    </View>
  );
};

const styles = StyleSheet.create({
  complet: {
    backgroundColor: COLORS.blanccasse,
    flex: 1,

  },
  shadow: {
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.23,
    shadowRadius: 2.62,
    elevation: Platform.OS === 'android' ? 4 : 0,
  },

  container: {
    marginTop: 20,
    backgroundColor: COLORS.white,
    alignItems: 'center',
    justifyContent: 'center',
  },
  headerContainer: {
    marginTop: 30,
    flexDirection: 'row',
    alignItems: 'flex-end',
    justifyContent: 'flex-start', // Alignement du contenu à gauche
    // marginBottom: 16,

  },
  logo: {
    width: 30,
    height: 30,
    marginRight: 8,
  },
  headerText: {
    fontSize: 25,
    fontWeight: 'bold',
    color: COLORS.grey,
  },
  searchContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#f2f2f2',
    borderRadius: 8,
    paddingHorizontal: 12,
    marginTop: 10,
    backgroundColor: COLORS.blanccasse,
    marginBottom: 10,
    width: '95%',
  },
  searchInput: {
    flex: 1,
    height: 40,
    fontSize: 16,
    color: '#333',
  },
  searchIcon: {
    marginLeft: 8,
  },
  item: {
    backgroundColor: COLORS.blue,
    marginTop: 10,
    paddingVertical: 8,
    paddingHorizontal: 24,
    marginHorizontal: 8,
    borderRadius: 8,
  },
  selectedItem: {
    backgroundColor: COLORS.red,
  },
  itemText: {
    color: COLORS.beige,
    fontSize: 16,
    fontWeight: 'bold',
  },

  selectedItem: {
    backgroundColor: COLORS.red,
  },

  amis: {

    backgroundColor: COLORS.blue,
  },

  selectedAmis: {

    backgroundColor: COLORS.red,
  },

});

export default Menuaccept;