#from flask import Flask, request
#from flask_socketio import SocketIO, emit

from flask import Flask, request, jsonify
from flask_socketio import SocketIO, emit
from connexion.myconnection import get_connection

app = Flask(__name__)
app.config['SECRET_KEY'] = 'your secret key'
socketio = SocketIO(app)

IP_ADDRESS = '192.168.85.147'
PORT = 1200

@app.route('/api/mesnotifications', methods=['POST'])
def handle_notifications():
    
    
    conn = get_connection()
    cursor = conn.cursor()
    
    # Récupérer les données en format JSON
   
    
    # Exécuter la requête SQL
    cursor.execute("SELECT id, nom, postnom, prenom, email, password, avatar, telephone FROM users")
    users = cursor.fetchall()

    # Conversion des données en format JSON
    user_data = []
    for id, nom, postnom, prenom, email, password, avatar, telephone in users:
        image_url = f'/static/Image/{avatar}'
        user_data.append({
            'id': id,
            'nom': nom,
            'postnom': postnom,    
            'prenom': prenom,
            'email': email,
            'password': password,
            'avatar': image_url,
            'telephone': telephone,
            'url': avatar
        })

    
    
    
    
    
    
    
    
    
    
    donnees = request.form.get('donnees')
    socketio.emit('v', {'data': user_data , 'nom':donnees})
    return  jsonify(user_data)

@socketio.on('connect')
def handle_connect():
    print('Client connected')

@socketio.on('message')
def handle_message(data):
    print(f'Received message: {data}')

if __name__ == '__main__':
    socketio.run(app, host=IP_ADDRESS, port=PORT)


#IP_ADDRESS = '192.168.68.103'
#PORT = 1200



#app = Flask(__name__)
#app.config['SECRET_KEY'] = '142554444'
#socketio = SocketIO(app)

#@socketio.on('connect')
#def handle_connect():
  #  print('Client connected')

#@socketio.on('disconnect')
#def handle_disconnect():
    #print('Client disconnected')

#@socketio.on('new_notification')
#def handle_new_notification(data):
   # print(f'New notification: {data}')
   # emit('v', data, broadcast=True)
    
   



#if __name__ == '__main__':
    socketio.run(app, host=IP_ADDRESS, port=PORT)
    
    
    
    
    from flask import Flask
#from flask_socketio import SocketIO, emit
