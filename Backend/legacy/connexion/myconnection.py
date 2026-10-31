


import mysql.connector

# Définir les informations de connexion à la base de données MySQL
config = {
    'user': 'root',
    'password': 'admin',
    'host': 'localhost',
    'database': 'securite_sociale',
    'raise_on_warnings': True
}

def get_connection():
    return mysql.connector.connect(**config)