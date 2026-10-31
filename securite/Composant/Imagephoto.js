import * as ImagePicker from 'expo-image-picker';
import { useEffect, useState } from 'react';
import { Image, StyleSheet, View, Button, TextInput, Alert, Text, TouchableOpacity } from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import COLORS from '../Couleurs/COLORS';




export default function Imagephoto({pickImage, image, urlimage, defaultImage, setdefaultImage}) {





  return (
    <View style={styles.container}>
 

{image  ?  (
        <View style={styles.imageContainer}>
          <Image source={{ uri: image.uri }} style={styles.image} />
          <TouchableOpacity style={styles.iconContainer} onPress={pickImage}>
            <Icon name="photo-camera" size={15} color="#000" />
          </TouchableOpacity> 
        </View>
      ):(
       // '../assets/ordinateur.jpg'  <Image source={{uri: urlimage}} style={styles.image} />  <Image source={require(t)} style={styles.image} />
        <View style={styles.imageContainer}>
      
     
      <Image  source={defaultImage} style={styles.image} />
        <TouchableOpacity style={styles.iconContainer} onPress={pickImage}>
          <Icon name="photo-camera" size={18} color="#000" />
        </TouchableOpacity> 
      </View>
      
      
      
      )
      
      }
    
      {image && (
        <View>
            {/*      <Text  style={styles.imagetext}>Image sélectionnée :</Text>       */}  
             {/*        <Text  style={styles.fichier}>Nom de fichier : {image.fileName}</Text>       */} 
              {/*       <Text style={styles.fichier}>URI de l'image : {image.uri}</Text>      */} 
        
    
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
   // flex: 1,
    backgroundColor: COLORS.blanccasse,
    alignItems: 'center',
   justifyContent: 'center',
 },
  input: {
    height: 40,
    width: '80%',
    borderColor: COLORS.grey,
    borderWidth: 1,
    marginVertical: 10,
    paddingHorizontal: 10,
    borderRadius:10
  },
  imageContainer: {
    marginVertical: 10,
    width: '90%',
    marginBottom:20
   
  },
  image: {
    width: 180,
    height: 180,
    borderRadius:90,
    borderColor:COLORS.grey,
    borderWidth:0.2,
    resizeMode: 'cover',
    aspectRatio: 1,
   // marginLeft:20,
    //marginTop:50,
    
  },
  imagetext:{
    fontWeight:'bold',
    fontSize:24,
    marginLeft:20


  },
  fichier:{
   // fontWeight:'bold',
    fontSize:16,
    marginLeft:20

  },

  iconContainer: {
    position: 'absolute',
    bottom: 20,
    right: 0,
    backgroundColor: COLORS.blanccasse,
    padding: 10,
    borderRadius: 25,
    shadowColor: COLORS.black,
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
    elevation: 5,
  },
});