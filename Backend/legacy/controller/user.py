from flask import jsonify, request, send_from_directory, send_file, url_for
from  connexion. myconnection  import get_connection
from flask_bcrypt import Bcrypt
import os
from flask_jwt_extended import jwt_required, get_jwt_identity, JWTManager, create_access_token


from flask_socketio import SocketIO, join_room, emit
#select users.id AS id,  users.nom AS  nom , users.postnom  AS postnom ,  users.prenom AS  prenom ,  users.password AS password , users.email AS  email ,  users.avatar  AS  avatar , users.telephone  AS  telephone from  users  where !(users.id in (select demandes.recev_id  from   demandes   where  demandes.envoi_id = '1'))




def downloadi():
    
   
    conn = get_connection()
    cursor = conn.cursor()
    
  
    #query = "SELECT * FROM fichiers WHERE id = %s"
    #cursor.execute(query, (id,))
    #file_info = cursor.fetchone()

    #cursor.close()
   

    #return  file_info[1]
   
      
def download_pdf(id):
    # Récupérer le nom du fichier PDF à partir de la base de données
    cursor = db.cursor()
    query = "SELECT * FROM fichiers WHERE id = %s"
    cursor.execute(query, (id,))
    fiche = cursor.fetchone()
    filename=fiche[1]

    if filename:
        # Construire le chemin absolu du fichier PDF en ajoutant le dossier "mesfichiers"
        file_path = os.path.join(os.path.dirname(__file__), 'GsCarriere/mesfichiers', filename)
        file_paths = os.path.normpath(file_path)


        # Vérifier si le fichier existe
        if os.path.isfile(file_path):
            # Envoyer le fichier PDF en tant que réponse
            return send_file(file_path, mimetype='application/pdf', as_attachment=True)
        else:
            #return "Le fichier demandé n'existe pas.", 404
            return jsonify(file_paths) 
    else:
        return "Le fichier demandé n'existe pas.", 404
      # return  jsonify("famba")
    
    
def verifieremail():
    try:
        email = request.form.get('email')
        conn = get_connection()
        cursor = conn.cursor()
        query = "SELECT COUNT(*) FROM users WHERE email = %s"
        cursor.execute(query, (email,))
        count = cursor.fetchone()[0]

        if count > 0:
            return('email')
        else:
            return("email n'existe pas")
    except Exception as e:
        return(f"Une erreur est survenue : {e}")
     
  
def getuserss():
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM users")
        objets = cursor.fetchall()
        headers = [desc[0] for desc in cursor.description]
        data = [dict(zip(headers, row)) for row in objets]

        user_dir = os.path.expanduser("~")
        image_path = os.path.join(user_dir, 'Downloads', 'Securite_sociale', 'BD', 'Image', 'user.png')
        #image_url = url_for('static', filename=os.path.relpath(image_path, app.static_folder))
        #return image_path
       # return {'data': data, 'image_url': image_path}
    finally:
        cursor.close()
        conn.close()
        
        
        
 
        
def getuser():
    try:
        # Connexion à la base de données
        conn = get_connection()
        cursor = conn.cursor()

        # Récupération des données des utilisateurs
        cursor.execute("SELECT id, nom, postnom, prenom, email, password, avatar, telephone FROM listeamis")
        users = cursor.fetchall()

        # Conversion des données en format JSON
        data = []
        for id, nom, postnom, prenom, email, password, avatar, telephone in users:
            image_url = f'/static/Image/{avatar}'
            data.append({
                'id': id,
                'nom': nom,
                'postnom': postnom,    
                'prenom': prenom,
                'email': email,
                'password': password,
                 'avatar': image_url,
                'telephone': telephone,
                'url':avatar
            })

        return data

    except Exception as e:
       
        print(f"Erreur lors de la création de la localisation : {str(e)}")
        return 'Erreur'
    
        
    
    
def getuserpage(page=1, per_page=10, envoi_id=None):
    try:
        # Connexion à la base de données
        conn = get_connection()
        cursor = conn.cursor()

        # Récupération du nombre total d'utilisateurs
        cursor.execute("SELECT COUNT(*) FROM users WHERE users.id NOT IN (SELECT demandes.recev_id FROM demandes WHERE demandes.envoi_id = %s)", (envoi_id,))
        total_users = cursor.fetchone()[0]

        # Calcul de l'offset et de la limite pour la pagination
        offset = (page - 1) * per_page
        limit = per_page

        # Récupération des données des utilisateurs avec la pagination
        cursor.execute("SELECT users.id AS id, users.nom AS nom, users.postnom AS postnom, users.prenom AS prenom, users.email AS email, users.password AS password,  users.avatar AS avatar, users.telephone AS telephone FROM users WHERE users.id NOT IN (SELECT demandes.recev_id FROM demandes WHERE demandes.envoi_id = %s) LIMIT %s OFFSET %s", (envoi_id, limit, offset))
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
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
def getuserpageddd(page=1, per_page=10, envoi_id=None):
    try:
        # Connexion à la base de données
        conn = get_connection()
        cursor = conn.cursor()

        # Récupération du nombre total d'utilisateurs
        cursor.execute("SELECT COUNT(*) FROM users")
        total_users = cursor.fetchone()[0]

        # Calcul de l'offset et de la limite pour la pagination
        offset = (page - 1) * per_page
        limit = per_page

        # Récupération des données des utilisateurs avec la pagination
        #cursor.execute("SELECT id, nom, postnom, prenom, email, password, avatar, telephone FROM listeamis LIMIT %s OFFSET %s", (limit, offset))
       
        cursor.execute("SELECT users.id AS id, users.nom AS nom, users.postnom AS postnom, users.prenom AS prenom, users.password AS password, users.email AS email, users.avatar AS avatar, users.telephone AS telephone FROM users WHERE users.id NOT IN (SELECT demandes.recev_id FROM demandes WHERE demandes.envoi_id = %s)LIMIT %s OFFSET %s", (limit, offset,envoi_id)),
    
       
       
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
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
def  create_user():
    bcrypt = Bcrypt()
    conn = get_connection()
    cur = conn.cursor()

    try:
        nom = request.form.get('nom')
        postnom = request.form.get('postnom')
        prenom = request.form.get('prenom')
        email = request.form.get('email')
        password = request.form.get('password')
       # image = request.form.get('image')
        telephone = request.form.get('telephone')
        hashed_password = bcrypt.generate_password_hash(password).decode('utf-8')
        #cursor = db.cursor()
       
        if 'image' in request.files:
            file = request.files['image']
            filename = file.filename

            image_path = os.path.join('static/Image', filename)
            file.save(image_path)

            cur.execute("INSERT INTO users (nom, postnom, prenom, email, password, avatar,telephone) VALUES (%s,%s,%s,%s,%s,%s,%s)", (nom,postnom, prenom, email, hashed_password, filename, telephone,))
            conn.commit()
            cur.close()

            return 'Opération effectuée avec succès.'
        else:
            monimage = "user.png"
            cur.execute("INSERT INTO users (nom, postnom, prenom, email, password, avatar,telephone) VALUES (%s,%s,%s,%s,%s,%s,%s)", (nom,postnom, prenom, email, hashed_password, monimage, telephone,))
            conn.commit()
         
            cur.close()

            return 'Fichier image  enregistré avec succès.'

    except Exception as e:
        conn.rollback()
        print(f"Erreur lors de la création de la localisation : {str(e)}")
        return 'Erreur lors de la création de la publication'
    
    
    
    
def login():
    
    try:
        conn = get_connection()
        cursor = conn.cursor()
        bcrypt = Bcrypt()
        email = request.form.get('email')
        password = request.form.get('password')

        # Vérification de l'utilisateur dans la base de données
        cursor.execute("SELECT * FROM users WHERE email = %s", (email,))
        user = cursor.fetchone()
        conn.close()

        if user and bcrypt.check_password_hash(user[5], password):
            # Création du token d'accès
            access_token = create_access_token(identity=user[0])
            response = {
                'access_token': access_token,
                'user': {
                    'id': user[0],
                    'nom': user[1],
                    'postnom': user[2],
                    'prenom': user[3],
                    'email': user[4]
                }
            }
            return response
        else:
            return 'password'
    except Exception as e:
        # Gérer les exceptions ici
        print(f"Une erreur est survenue : {e}")
        return 'Une erreur est survenue', 500

