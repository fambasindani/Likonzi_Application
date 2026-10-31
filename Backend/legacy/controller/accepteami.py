
from flask import jsonify, request, send_from_directory, send_file, url_for
from  connexion. myconnection  import get_connection
from flask_bcrypt import Bcrypt
import os
from flask_jwt_extended import jwt_required, get_jwt_identity, JWTManager, create_access_token
import datetime

  
def getaccepte(page=1, per_page=10, envoi_id=None):
    try:
        # Connexion à la base de données
        conn = get_connection()
        cursor = conn.cursor()
        confirmation="0"
        datedemande = datetime.datetime.now()
        # Récupération du nombre total d'utilisateurs
        cursor.execute("SELECT COUNT(*) FROM demandes WHERE  envoi_id=%s   and confirmation=%s ", (envoi_id, confirmation,))
        total_users = cursor.fetchone()[0]

        # Calcul de l'offset et de la limite pour la pagination
        offset = (page - 1) * per_page
        limit = per_page

        # Récupération des données des utilisateurs avec la pagination
        cursor.execute("SELECT  id , nom , postnom, prenom, email, password, avatar, telephone, idc FROM listedemandes WHERE recev_id=%s  LIMIT %s OFFSET %s", (envoi_id, limit, offset))
        users = cursor.fetchall()

        # Conversion des données en format JSON
        user_data = []
        for id, nom, postnom, prenom, email, password, avatar, telephone, idc in users:
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
                'idc':idc,
                'url':avatar
            })

        # Calcul du nombre total de pages
        total_pages = (total_users + per_page - 1) // per_page

        return {
            'data': user_data,
            'total_pages': total_pages,
            'current_page': page
        }

    except Exception as e:
        print(f"Erreur lors de la création de la localisation : {str(e)}")
        return 'Erreur'    
    
    
    


def create_accepter():
    conn = get_connection()
    cursor = conn.cursor()

    try:
        #recev_id = request.form.get('recev_id')
        #envoi_id = request.form.get('envoi_id')
        id = request.form.get('id')
        confirmation = "1"
       # datelocalisation = request.form.get('datelocalisation')
        #datedemande = datetime.datetime.now()
       

        cursor.execute("UPDATE demandes SET confirmation=%s WHERE id=%s ", (confirmation, id))
        conn.commit()
        return 'acceptation reussie'
    except Exception as e:
        conn.rollback()
        print(f"Erreur lors de la création de la localisation : {str(e)}")
        return "Erreur lors de l'acceptation de demande"
          
    
    
def  delete_accepter(id):
    conn = get_connection()
    cursor = conn.cursor()

    try:
        cursor.execute("DELETE FROM demandes WHERE id=%s", (id,))
        conn.commit()
    
        return 'Opération effectuée'
    except Exception as e:
        conn.rollback()
        print(f"Erreur lors de la création de la localisation : {str(e)}")
        return "Erreur d'opération"
          
    
    
           
def getnotification(envoi_ids):
    try:
        # Connexion à la base de données
        conn = get_connection()
        cursor = conn.cursor()
       
        contenu="Je suis en danger"
       # recev_id = request.form.get('recev_id')
        confirmation="0"
        # Récupération des données des utilisateurs
        #cursor.execute("SELECT recev_id, envoi_id FROM demandes WHERE envoi_id=%s AND confirmation=%s "(envoi_id, confirmation))
        cursor.execute("SELECT recev_id, envoi_id FROM demandes WHERE envoi_id=%s AND confirmation=%s", (envoi_ids, confirmation))
        users = cursor.fetchall()

        # Conversion des données en format JSON
        data = []
        for recev_id, envoi_id in users:
            
            data.append({
                'recev_id': recev_id,
                'envoi_id': envoi_id,
                   
               
            })
            
            datedemande = datetime.datetime.now()
            cursor.execute("INSERT INTO notifications (recev_id,envoi_id, datenotification, contenu) VALUES (%s,%s, %s, %s)", (recev_id,envoi_id, datedemande, contenu))
            conn.commit()

        #return 'demande envoyée'
            

        return data

    except Exception as e:
       
        print(f"Erreur lors de la création de la localisation : {str(e)}")
        return 'Erreur'
    