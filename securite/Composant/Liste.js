import { View, Text, FlatList, StyleSheet, style, ActivityIndicator, RefreshControl } from 'react-native'
import React from 'react'

export default function Listflast({ data, renderItem, fetchUserData, Loading}) {
  return (
   <FlatList
    
    data={data}
     
     renderItem={renderItem}
      //renderItem={renderItem}
     keyExtractor={(item) => item.id.toString()}
    // initialNumToRender={20}
     // key={(item) => item.id.toString()}
      onEndReached={fetchUserData}
      onEndReachedThreshold={0.1}
      ListFooterComponent={()=>{
        return(

        <View style={{ width: '90%', height: 60, justifyContent: 'center', alignContent: 'center' }}>
            {Loading &&
            <ActivityIndicator size={'large'} /> }

         </View>
        )}
    
      }
     // onEndReached={() => setIndexCounter(indexCounter + 1)} 
    // refreshing={isRefreshing}
    // onRefresh={fetchUserData}
    />


  
  )
}
