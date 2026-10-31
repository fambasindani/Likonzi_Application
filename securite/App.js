import { StatusBar } from 'expo-status-bar';
import { StyleSheet, Text, View } from 'react-native';
import Localisation from './Composant/Localisation';
import Carte from './Composant/Carte';
import Input from './Composant/Inputtext';
import MonMenu from './Composant/Monmenu';
import Fleche from './Composant/Fleche';
import Ts from './Composant/Ts';


import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import Register from './Screens/Inscriptionscreen';
import Loginscreen from './Screens/Loginscreen';
import Menudemande from './Composant/Menudemande';
import Passwordscreen from './Screens/Passwordscreen';
import Listeamis from './Composant/Listeamis';
import ModalPopup from './Composant/ModalPopup';
import Menus from './Composant/Menus';


import Cartemaps from './Composant/Cartemaps';
import MyComponent from './Composant/Pagination';
import Listeami from './Composant/Pagination';
import NotificationComponent from './Composant/Notification';
import NotificationScreens from './Composant/NotificationScreen';
import NotificationScreenss from './Composant/Socket';
import Notificationexpo from './Composant/Notificationexpo';
import Malistesocket from './Composant/Malistesocket';
import Menuaccept from './Composant/Menuaccept';
import TrafficMap from './Composant/TrafficMap ';
import TrafficMaps from './Composant/Mampstrafic';
import SatelliteMap from './Composant/SatelliteMap ';
const stack = createNativeStackNavigator()

const App = () => {
  return (




    <NavigationContainer>

     

      <stack.Navigator screenOptions={{ headerShown: false }}>

      

    

      <stack.Screen
          name='Loginscreen'
          component={Loginscreen}
        />

        <stack.Screen
          name='Menuaccept'
          component={Menuaccept}
        />


      <stack.Screen
          name='Malistesocket'
          component={Malistesocket}
        />

         
      <stack.Screen
          name='Listeamis'
          component={Listeamis}
        />
     



      <stack.Screen
          name='Listeami'
          component={Listeami}
        />




     


        



     
      
    
      

     


        <stack.Screen


          name='Menus'
          component={Menus}
        />



     

        <stack.Screen


          name='Register'
          component={Register}
        />

        <stack.Screen
          name='Ts'
          component={Ts}
        />
      

     
      <stack.Screen
          name='MonMenu'
          component={MonMenu}
        />


        <stack.Screen
          name='Passwordscreen'
          component={Passwordscreen}
        />


        <stack.Screen
          name='Carte'
          component={Carte}
        />





      </stack.Navigator>



      

    </NavigationContainer>
  );
};

export default App;