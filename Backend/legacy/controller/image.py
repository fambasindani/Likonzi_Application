from flask import jsonify, request, send_from_directory, send_file
from  connexion. myconnection  import get_connection

import os
from flask_jwt_extended import jwt_required, get_jwt_identity, JWTManager, create_access_token





def downloadpdf():
    
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
    
    
    
    
    
    
def upload_image():
    
    conn = get_connection()
    cur = conn.cursor()
    
    if 'image' in request.files:
        file = request.files['image']
        filename = file.filename
        
        image_path = os.path.join('Image', filename)
        file.save(image_path)
      
        #file.save('Image/' + filename)
        #file.save('/home/famba/mysite/GsCarriere/mesfichiers/' + filename)
        
        
        cur.execute("INSERT INTO imgs (image) VALUES (%s)", (filename,))
        conn.commit()
        cur.close()
       # return 'uri:'+image_path +"  filename:"+filename
         
        return 'Fichier image  enregistré avec succès.'
    else:
        monimage="user.png"
        cur.execute("INSERT INTO imgs (image) VALUES (%s)", (monimage,))
        conn.commit()
        cur.close()
      
       # return 'Aucun fichier image n\'a été fourni.'
        return  'Fichier image  enregistré avec succès.'