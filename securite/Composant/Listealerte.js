import React, { useEffect, useState } from 'react';
import { View, Text, TouchableOpacity, Alert, SafeAreaView, Image } from 'react-native';
import COLORS from '../Couleurs/COLORS';
import Listflast from './Liste';
import ModalPopup from './ModalPopup';
import ApiUrl from './ApiUrl';
import axios from 'axios';
import { FontAwesome5 } from '@expo/vector-icons';
import ApiUrlbis from './ApiUrlbis';
import { useNavigation } from '@react-navigation/native';
import Cartemaps from './Cartemaps';




const Listealerte = ({ mydata}) => {
  const [modalVisible, setModalVisible] = useState(false);
  const [phone, setphone] = useState(null);
  const [email, setemail] = useState(null);
  const [nom, setnom] = useState(null);
  const [prenom, setprenom] = useState(null);
  const [modalVisiblemap, setModalVisiblemap] = useState(false);


  const urlBIS = ApiUrlbis({ endpoint: 'static/Image/' });


 // const fetchUserData = async () => {
  //  try {
   //   const url = ApiUrl({ endpoint: 'avatar/user.png' });
    //  const response = await axios.get(url, { responseType: 'arraybuffer' });
     // const uint8Array = new Uint8Array(response.data);
     // const base64String = btoa(String.fromCharCode(...uint8Array));
    //  setmonavatar(`data:image/png;base64,${base64String}`);
    //  console.log(myitem);
   // } catch (error) {
   //   console.error('Error fetching user data:', error);
   // }
 // };

 /// useEffect(() => {
   // fetchUserData();
 // }, [myitem]);

  const toggleModal = () => {
    setModalVisible(!modalVisible);
  };



  const renderItem = ({ item, index }) => {

    
    const Actionmaps = () => {
    
        setModalVisiblemap(true)
    }



    const handleConfirm = () => {
      Alert.alert(
        'Gestion de Stock',
        'Voulez-vous vraiment supprimer ' + item.description + ' ?',
        [
          {
            text: 'Annuler',
            onPress: () => console.log('ok'),
            style: 'cancel',
          },
          {
            text: 'Supprimer',
            onPress: () => {
              // Logique de suppression ici
              console.log('Supprimé');
              toggleModal();
            },
            style: 'destructive',
          },
        ]
      );
    };
    
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
          <Text style={styles.price}>{item.postnom}</Text>
          <View style={styles.buttonContainer}>
          <TouchableOpacity style={[styles.button, styles.buttonRow] } onPress={Actionmaps}>
              <FontAwesome5 name="map-marker-alt" size={18} color={COLORS.white} />
              <Text style={styles.buttonText}>Maps</Text>
            </TouchableOpacity>
            <TouchableOpacity style={[styles.button, styles.deleteButton, styles.buttonRow]} onPress={handdetails}>
            <FontAwesome5 name="trash-alt" size={18} color={COLORS.white} />
              <Text style={[styles.buttonText, styles.deleteButtonText]}>Supprimer</Text>
            </TouchableOpacity>
          </View>
        </View>
      </View>
    );
  };

  return (
      <View style={styles.container}>
        
    
          <Listflast data={mydata} renderItem={({ item, index }) => renderItem({ item, index: index + 1 })} />
          <ModalPopup nom={nom} prenom={prenom} phone={phone} email={email} modalVisible={modalVisible} setModalVisible={setModalVisible} toggleModal={toggleModal} />
          <Cartemaps modalVisible={modalVisiblemap} setModalVisible={setModalVisiblemap}/>
       

     

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
    resizeMode: 'contain',
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
    paddingHorizontal: 14,
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

export default Listealerte;