#!/bin/bash

# Use environment variables if set, otherwise use defaults
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-user}"
DB_PASSWORD="${DB_PASS:-}"
DB_NAME="${DB_NAME:-example}"
CREATION_DIR="./creation_bdd"

# Vérifier que le répertoire de création existe
if [ ! -d "$CREATION_DIR" ]; then
    echo "Erreur: Le répertoire $CREATION_DIR n'existe pas."
    exit 1
fi

# Construire la chaîne de connexion
connection_params="-h \"$DB_HOST\" -p \"$DB_PORT\" -U \"$DB_USER\""

# Ajouter le paramètre de mot de passe si défini
if [ -n "$DB_PASSWORD" ]; then
    export PGPASSWORD="$DB_PASSWORD"
fi

# Concaténer tous les fichiers SQL
cat "$CREATION_DIR"/*.sql > database.sql

# Exécuter le script SQL
echo "Création de la base de données $DB_NAME..."
if psql $connection_params -d "$DB_NAME" -f database.sql; then
    echo "Création réussie!"
else
    echo "Erreur lors de la création."
    rm database.sql
    [ -n "$DB_PASSWORD" ] && unset PGPASSWORD
    exit 1
fi

# Nettoyer
rm database.sql
[ -n "$DB_PASSWORD" ] && unset PGPASSWORD
