
import React, { useEffect, useState } from 'react';
import { View, Text, TouchableOpacity, Alert, SafeAreaView, Image } from 'react-native';
import COLORS from '../Couleurs/COLORS';
import Listflast from './Liste';
import ModalPopup from './ModalPopup';
import ApiUrl from './ApiUrl';
import axios from 'axios';
import { FontAwesome5 } from '@expo/vector-icons';
import ApiUrlbis from './ApiUrlbis';
import AsyncStorage from '@react-native-async-storage/async-storage';


const Listenotification = ({handdelete, mydata, SetLoading, Loading, fetchUserData, handleConfirm}) => {
  const [modalVisible, setModalVisible] = useState(false);
  const [phone, setphone] = useState(null);
  const [email, setemail] = useState(null);
  const [nom, setnom] = useState(null);
  const [prenom, setprenom] = useState(null);
  const [confirmation, setconfirmation] = useState('');
 // const [UserData, setUserData] = useState([]);
 
  //const [Loading, SetLoading] = useState(false);

  const urlBIS = ApiUrlbis({ endpoint: 'static/Image/' });




    
    useEffect(() => {
       // fetchUserData();
    }, []);

  const toggleModal = () => {
    setModalVisible(!modalVisible);
  };







  const renderItem = ({ item, index }) => {

  

   const verificationdemande = async() => {
    const urlconfirmation = ApiUrl({ endpoint: 'verifierdemande' });
   // Alert.alert('Message', item.id)
   try {
   
    //const response = await axios.get(urlconfirmation/${item.id});
    const response = await axios.get(`${urlconfirmation}/${item.id}`);
    const newData = response.data;
    Alert.alert(newData)
    console.log(newData);
    setconfirmation(newData)
  } catch (error) {
    console.error('Error fetching user data:', error);
  } finally {
   
  }



   

  };


  const url = ApiUrl({ endpoint: 'createdemande' });








      //handleConfirm(item);

 
    const handdetails  = () => {
      // Logique d'édition ici
      console.log('Confirmé');
      
        setphone(item.telephone)
        setemail(item.email)
        setnom(item.nom)
        setprenom(item.prenom)

      toggleModal();
    };

    return (
      <View style={styles.itemContainer}>
        <TouchableOpacity style={styles.indexContainer}>
        
          
         <Image source={{ uri: urlBIS+item.url }} style={[styles.image, { width: 90, height: 90 }]} /> 
         
       
        </TouchableOpacity>
        <View style={styles.descriptionContainer}>
          <Text style={styles.description}>{item.prenom}</Text>
          <Text style={styles.price}>{item.nom}</Text>
          <View style={styles.buttonContainer}>

            <TouchableOpacity style={[styles.button, styles.buttonRow]} onPress={() => handleConfirm(item)}>
              <FontAwesome5 name="check" size={18} color={COLORS.white} />
              <Text style={styles.buttonText}>Confirmer</Text>
            </TouchableOpacity>
            <TouchableOpacity style={[styles.button, styles.deleteButton, styles.buttonRow]} onPress={() =>handdelete(item)}>
              <FontAwesome5 name="trash-alt" size={18} color={COLORS.white} />
              <Text style={[styles.buttonText, styles.deleteButtonText]}>Supprimer</Text>
            </TouchableOpacity>
          </View>
        </View>
      </View>
    );
  };

  return (
    //data={UserData}
    <View style={styles.container}>

      
      
      <Listflast handleConfirm={handleConfirm} SetLoading={SetLoading} Loading={Loading} data={mydata} fetchUserData={fetchUserData} renderItem={({ item, index }) => renderItem({ item, index: index + 1 })} />
      <ModalPopup nom={nom} prenom={prenom} phone={phone} email={email} modalVisible={modalVisible} setModalVisible={setModalVisible} toggleModal={toggleModal} />
     

    </View>
  );
};

const styles = {
  container: {
    flex: 1,
  },
  itemContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.grey,
  },
  image: {
    width: 90,
    height: 90,
    borderRadius: 50,
    resizeMode: 'cover',
   // aspectRatio: 16 / 9,
    aspectRatio: 1,
  },
  descriptionContainer: {
    flex: 1,
    marginLeft: 16,
  },
  description: {
    fontSize: 16,
    fontWeight: 'bold',
  },
  buttonContainer: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    alignItems: 'center',
    marginTop: 12,
  },
  button: {
    backgroundColor: COLORS.blue,
    paddingVertical: 10,
    paddingHorizontal: 8,
    borderRadius: 8,
    marginLeft: 8,
    
  },
  deleteButton: {
    backgroundColor: COLORS.red,
  },
  buttonText: {
    color: COLORS.white,
    fontSize: 14,
    fontWeight: 'bold',
    paddingHorizontal:5
  },
  deleteButtonText: {
    color: COLORS.white,
  },
  price: {
    color: COLORS.grey,
    fontSize: 15,
  },
  buttonRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  
  },
};

export default Listenotification;