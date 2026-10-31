from flask import Flask, jsonify, send_from_directory,request
from flask_cors import CORS
from controller.localisation import create_localisation, recupererid, update_localisation
from controller.image import upload_image
from controller.email import send_email
from controller.user import create_user, verifieremail, login, getuser, getuserpage
from flask_jwt_extended import jwt_required, get_jwt_identity, JWTManager, create_access_token

from flask_socketio import SocketIO, join_room, emit
from flask_socketio import emit, join_room, leave_room
from connexion.myconnection import get_connection
import os
from controller.demande import create_demande, verifierdemande
from controller.accepteami import getaccepte,create_accepter, delete_accepter,getnotification


IP_ADDRESS = '192.168.85.147'
PORT = 1200

app = Flask(__name__)

CORS(app)
socketio = SocketIO(app)
user_tokens = {}

app.config['JWT_SECRET_KEY'] = '1254857@fb'

jwt = JWTManager(app)

#route pour publication

@app.route('/api/createpublication', methods=['POST'])
#@jwt_required()
def api_create_localisation():
    return jsonify(create_localisation())



#Route pour demande  

@app.route('/api/createdemande', methods=['POST'])
#@jwt_required()
def api_create_demande():
    return jsonify(create_demande())



@app.route('/api/verifierdemande/<int:recev_id>', methods=['GET'])
#@jwt_required()
def api_create_verifierdemande(recev_id):
    return jsonify(verifierdemande(recev_id))


@app.route('/api/recupererid', methods=['GET'])
#@jwt_required()
def api_get_recupererid():
    return jsonify(recupererid())

@app.route('/api/update_localisation', methods=['PUT'])
#@jwt_required()
def api_update_localisation():
    return jsonify(update_localisation())


@app.route('/api/send_email', methods=['POST'])
def api_send_email():
    return jsonify(send_email())


@app.route('/api/upload_image', methods=['POST'])
def api_upload_image():
    return jsonify( upload_image())

@app.route('/api/create_user', methods=['POST'])
def api_create_user():
    return jsonify(create_user())


@app.route('/api/verifieremail', methods=['POST'])
def api_verifieremail():
    return jsonify(verifieremail())

@app.route('/api/login', methods=['POST'])
def api_login():
    return jsonify(login())

@app.route('/api/getuser', methods=['get'])
def api_getuser():
    return jsonify(getuser())





  
  
#@app.route('/image/')
#def serve_user_image():
    #return send_from_directory('static/Image', 'user.png')

@app.route('/api/avatar/<string:filename>', methods=['GET'])
def serve_avatar(filename):
    return send_from_directory('static/Image', filename)

#route acceptation  
@app.route('/api/delete_accepter/<int:id>', methods=['DELETE'])
def sup_delete_accepter(id):
     return jsonify(delete_accepter(id))
 
@app.route('/api/getnotification/<int:id>', methods=['GET'])
def get_dgetnotification(id):
     return jsonify(getnotification(id))

@app.route('/api/create_accepter', methods=['PUT'])
def api_create_accepter():
    return jsonify(create_accepter())

@app.route('/api/getacceptation/<int:recev_id>', methods=['GET'])
def get_acceptation(recev_id):
    page = request.args.get('page', default=1, type=int)
    per_page = request.args.get('per_page', default=6, type=int)
    
    try:
        user_data = getaccepte(page, per_page, recev_id)
        return jsonify(user_data)
    except Exception as e:
        print(f"Erreur lors de la création de la localisation : {str(e)}")
        return 'Erreur', 500




@app.route('/api/getuserpage/<int:recev_id>', methods=['GET'])
def get_users(recev_id):
    page = request.args.get('page', default=1, type=int)
    per_page = request.args.get('per_page', default=6, type=int)
    
    try:
        user_data = getuserpage(page, per_page, recev_id)
        return jsonify(user_data)
    except Exception as e:
        print(f"Erreur lors de la création de la localisation : {str(e)}")
        return 'Erreur', 500
    
    
    
@app.route('/api/send_notifications', methods=['POST'])
#@jwt_required()

def notifications():
    conn = get_connection()
    cursor = conn.cursor()
    recipient_id = request.form['recipient_id']
    message = request.form['message']
    sender_id= request.form['id_sender']
    
    if recipient_id:
       # if recipient_id in user_tokens:
            query = "INSERT INTO notes (id_rec, messages, id_sender) VALUES (%s, %s, %s)"
            values = (recipient_id, message, sender_id)
            cursor.execute(query, values)
            conn.commit()

            # Envoyer la notification en temps réel via WebSocket
            socketio.emit('new_notification', {'recipient_id': recipient_id, 'message': message}, room=user_tokens[recipient_id])
            return jsonify({'message': 'Notification envoyée'})
        #else:
           # return jsonify({'error': 'Utilisateur introuvable'}), 404
    else:
        return jsonify({'error': 'Identifiant de l\'utilisateur destinataire invalide'}), 400
    
    

user_tokens = {}

@app.route('/api/mesnotifications', methods=['POST'])
def send_notifications():
    conn = get_connection()
    cursor = conn.cursor()
    recipient_id = request.form['recipient_id']
    message = request.form['message']
    sender_id = '1'  # Récupérer l'ID de l'expéditeur depuis la session
    
    # Vérifier si l'utilisateur existe dans la base de données
    query = "SELECT id, nom, postnom FROM users WHERE id = %s"
    cursor.execute(query, (recipient_id,))
    user = cursor.fetchone()
    
    if user:
        # Stocker les informations de l'utilisateur dans user_tokens
        user_id, nom, postnom = user[0], user[1], user[2]
        user_tokens[recipient_id] = {'id': user_id, 'nom': nom, 'postnom': postnom}
        
        query = "INSERT INTO mesnotification (id_rec, id_sender, messages) VALUES (%s, %s, %s)"
        values = (recipient_id, sender_id, message)
        cursor.execute(query, values)
        conn.commit()

        # Émettre l'événement 'new_notification' sur le canal correspondant à l'utilisateur
        socketio.emit('new_notification', {'recipient_id': recipient_id, 'message': message, 'id': user_id, 'nom': nom, 'postnom': postnom}, room=user_tokens[recipient_id]['id'])
        return jsonify({'message': 'Notification envoyée'})
    else:
        return jsonify({'error': 'Utilisateur introuvable'}), 404

@socketio.on('connect')
def handle_connect():
    print('Client connecté')

@socketio.on('disconnect')
def handle_disconnect():
    print('Client déconnecté')
    
    
if __name__ == '__main__':
    app.run(host=IP_ADDRESS, port=PORT, debug=True)