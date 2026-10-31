from flask import jsonify, request, send_from_directory, send_file, url_for
from  connexion. myconnection  import get_connection
from flask_bcrypt import Bcrypt
import os
from flask_jwt_extended import jwt_required, get_jwt_identity, JWTManager, create_access_token
import datetime




def create_demande():
    conn = get_connection()
    cursor = conn.cursor()

    try:
        recev_id = request.form.get('recev_id')
        envoi_id = request.form.get('envoi_id')
        confirmation = "0"
       # datelocalisation = request.form.get('datelocalisation')
        datedemande = datetime.datetime.now()
       

        cursor.execute("INSERT INTO demandes (recev_id,envoi_id, datedemande, confirmation) VALUES (%s,%s, %s, %s)", (recev_id,envoi_id, datedemande, confirmation))
        conn.commit()

        return 'demande envoyée'
    except Exception as e:
        conn.rollback()
        print(f"Erreur lors de la création de la localisation : {str(e)}")
        return "Erreur lors de l'envoi de demande"
      
    
       
def verifierdemande(recev_id):
    try:
        #recev_id = request.form.get('recev_id')
        conn = get_connection()
        cursor = conn.cursor()
        query = "SELECT COUNT(*) FROM demandes WHERE recev_id = %s"
        cursor.execute(query, (recev_id,))
        count = cursor.fetchone()[0]

        if count > 0:
            return('demande')
        
    except Exception as e:
        return(f"Une erreur est survenue : {e}")
     
    