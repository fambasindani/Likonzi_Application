import React, { useEffect, useState } from 'react';
import { View, Text, TouchableOpacity, Alert, SafeAreaView, Image } from 'react-native';
import COLORS from '../Couleurs/COLORS';
import Listflast from './Liste';
import ModalPopup from './ModalPopup';
import ApiUrl from './ApiUrl';
import axios from 'axios';
import { FontAwesome5 } from '@expo/vector-icons';
import ApiUrlbis from './ApiUrlbis';

const Listeami = ({ mydata}) => {
  const [modalVisible, setModalVisible] = useState(false);
  const [phone, setphone] = useState(null);
  const [email, setemail] = useState(null);
  const [nom, setnom] = useState(null);
  const [prenom, setprenom] = useState(null);
  const [UserData, setUserData] = useState([]);
  const [currentpage, setcurrentpage] = useState(0);
  const [Loading, SetLoading] = useState(false);

  const urlBIS = ApiUrlbis({ endpoint: 'static/Image/' });
//http://192.168.68.103:1200/api/getuserpage?page=2&per_page=3

    const fetchUserDataggg = async () => {
        try {
            const url = ApiUrl({ endpoint: 'avatar/user.png' });
            const response = await axios.get(url, { responseType: 'arraybuffer' });
            const uint8Array = new Uint8Array(response.data);
            const base64String = btoa(String.fromCharCode(...uint8Array));
            setmonavatar(`data:image/png;base64,${base64String}`);
            console.log(myitem);
        } catch (error) {
            console.error('Error fetching user data:', error);
           
        }
    };




    const fetchUserData= async () => {
        try {
            SetLoading(true)
          const nextpage=currentpage+1
          const url = `http://192.168.68.103:1200/api/getuserpage?page=${nextpage}&per_page=3`;
         // const url = 'http://192.168.68.103:1200/api/getuserpage?page=1&per_page=3';
          const response = await axios.get(url);
        
          const monData = response.data.data;
        
          console.log(response.data.data)
          setcurrentpage(nextpage)
          //setUserData(monData);
          setUserData([...UserData,...monData]);
         
          console.log(nextpage.toString())
         // 
          SetLoading(false)
         // 
         
        } catch (error) {
          SetLoading(false)
          console.error('Error fetching user data:', error);
        }
      };

    useEffect(() => {
       // fetchUserData();
    }, []);

  const toggleModal = () => {
    setModalVisible(!modalVisible);
  };

  const renderItem = ({ item, index }) => {



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
          <Text style={styles.price}>{item.nom}</Text>
          <View style={styles.buttonContainer}>
          <TouchableOpacity style={[styles.button, styles.buttonRow] } onPress={handleConfirm}>
              <FontAwesome5 name="users" size={18} color={COLORS.white} />
              <Text style={styles.buttonText}>Amis</Text>
            </TouchableOpacity>
            <TouchableOpacity style={[styles.button, styles.deleteButton, styles.buttonRow]} onPress={handdetails}>
            <FontAwesome5 name="info-circle" size={18} color={COLORS.white} />
              <Text style={[styles.buttonText, styles.deleteButtonText]}>Detail</Text>
            </TouchableOpacity>
          </View>
        </View>
      </View>
    );
  };

  return (
    <View style={styles.container}>
      <Listflast  SetLoading={SetLoading} Loading={Loading} getall={fetchUserData}   data={UserData} renderItem={({ item, index }) => renderItem({ item, index: index + 1 })} />
     
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

export default Listeami;