
import { View, Text } from 'react-native'
import React from 'react'
import Fleche from './Fleche'

import Menudemande from './Menudemande'
import { useNavigation } from '@react-navigation/native';

export default function Ts() {
    const navigation = useNavigation();

    const Actretour = () => {
       // navigation.navigate('Ts');
      
       navigation.goBack();
          



      };
    
  return (
    <View>
     <Fleche onPress={Actretour} titre="Amis"/>
     <Menudemande/>
    </View>
  )
}