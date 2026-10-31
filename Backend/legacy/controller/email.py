from flask import Flask, request, jsonify
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from  connexion. myconnection  import get_connection
from flask_bcrypt import Bcrypt
import os
from flask_jwt_extended import jwt_required, get_jwt_identity, JWTManager, create_access_token
import random

# Configurer les paramètres de connexion Gmail
GMAIL_USER = 'josiane.epi@gmail.com'
GMAIL_PASSWORD = 'txtuvmxtjumrzrdc'
SUBJECT = 'Changer mot de passe'
def send_email():
    bcrypt = Bcrypt()
    conn = get_connection()
    cursor = conn.cursor()

    random_number = random.randint(1000, 10000)
    recipient = request.form.get('email')
    new_password = str(random_number)
    hashed_password = bcrypt.generate_password_hash(new_password).decode('utf-8')

    query = "UPDATE users SET password = %s WHERE email = %s"
    cursor.execute(query, (hashed_password, recipient))
    conn.commit()
    cursor.close()

    # Récupérer les données du formulaire
    body = request.form.get('body', '')  # Valeur par défaut si 'body' n'est pas présent

    # Créer le message
    msg = MIMEMultipart()
    msg['Subject'] = SUBJECT
    msg['From'] = GMAIL_USER
    msg['To'] = recipient

    # Ajouter le corps du message seulement s'il n'est pas vide
    if body:
        msg.attach(MIMEText(body))
    msg.attach(MIMEText(new_password, 'plain'))

    # Envoyer le message
    try:
        with smtplib.SMTP('smtp.gmail.com', 587) as smtp:
            smtp.starttls()
            smtp.login(GMAIL_USER, GMAIL_PASSWORD)
            smtp.send_message(msg)
        return 'Email envoyé avec succès'
    except Exception as e:
        print(f"Une erreur est survenue : {e}")
        return 'Erreur lors de l\'envoi de l\'email'