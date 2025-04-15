#!/bin/bash

# Script pour créer automatiquement un fichier de migration
# Usage: ./create_migration.sh ["SQL statement"]

# Use environment variables if set, otherwise use defaults
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-user}"
DB_PASSWORD="${DB_PASS:-}"
DB_NAME="${DB_NAME:-example}"
DB_TEST_USER="${DB_TEST_USER:-user_test}"
DB_TEST_PASSWORD="${DB_TEST_PASS:-}"
DB_TEST_NAME="${DB_TEST_NAME:-example_test}"
PENDING_DIR="./pending_migration"

# Vérifier que le répertoire de migration existe
if [ ! -d "$PENDING_DIR" ]; then
    echo "Erreur: Le répertoire $MIGRATION_DIR n'existe pas."
    echo "Création du répertoire..."
    mkdir -p "$PENDING_DIR"
fi

# Vérifier qu'on est dans un dépôt git
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Erreur: Ce n'est pas un dépôt git."
    exit 1
fi

# Trouver le numéro de la dernière migration
LAST_NUMBER=0
if [ "$(ls -A $PENDING_DIR 2>/dev/null)" ]; then
    LAST_NUMBER=$(ls -1 $PENDING_DIR/*.sql 2>/dev/null | sed 's/.*\/\([0-9]\+\).*/\1/' | sort -n | tail -1)
fi

# Calculer le nouveau numéro (avec padding à 4 chiffres)
NEXT_NUMBER=$(printf "%04d" $((10#$LAST_NUMBER + 1)))
NEW_MIGRATION_FILE="$PENDING_DIR/$NEXT_NUMBER-pending.sql"

# Récupérer le contenu SQL
SQL_CONTENT=""
if [ $# -eq 0 ]; then
    # Si aucun argument n'est fourni, chercher le fichier migration.sql
    if [ -f "migration.sql" ]; then
        SQL_CONTENT=$(cat "migration.sql")
    else
        echo "Erreur: Aucun argument SQL fourni et aucun fichier migration.sql trouvé."
        exit 1
    fi
else
    # Utiliser l'argument fourni comme contenu SQL
    SQL_CONTENT="$1"
fi

# Créer le nouveau fichier de migration
echo "-- Migration $NEXT_NUMBER-$COMMIT_HASH" > "$NEW_MIGRATION_FILE"
echo "-- Date: $(date '+%Y-%m-%d %H:%M:%S')" >> "$NEW_MIGRATION_FILE"
echo "" >> "$NEW_MIGRATION_FILE"
echo "$SQL_CONTENT" >> "$NEW_MIGRATION_FILE"

echo "Fichier de migration créé: $NEW_MIGRATION_FILE"

# Fonction pour appliquer la migration à une base de données
apply_migration() {
    local db_user=$1
    local db_password=$2
    local db_name=$3
    local connection_params="-h $DB_HOST -p $DB_PORT -U $db_user"
    
    # Ajouter le paramètre de mot de passe si défini
    if [ -n "$db_password" ]; then
        export PGPASSWORD="$db_password"
    fi
    
    # Appliquer la migration
    echo "Application de la migration à la base de données $db_name..."
    if psql $connection_params -d "$db_name" -f "$NEW_MIGRATION_FILE"; then
        echo "Migration appliquée avec succès à $db_name!"
    else
        echo "Erreur lors de l'application de la migration à $db_name."
        [ -n "$db_password" ] && unset PGPASSWORD
        return 1
    fi
    
    [ -n "$db_password" ] && unset PGPASSWORD
    return 0
}

# Appliquer la migration à la base de données normale
apply_migration "$DB_USER" "$DB_PASS" "$DB_NAME"
normal_result=$?

# Appliquer la migration à la base de données de test
apply_migration "$DB_TEST_USER" "$DB_TEST_PASS" "$DB_TEST_NAME"
test_result=$?

# Récapitulatif
echo ""
echo "Récapitulatif:"
echo "- Nouveau fichier de migration: $NEXT_NUMBER-pending.sql"
echo "- Migration appliquée à la base normale: $([ $normal_result -eq 0 ] && echo "Succès" || echo "Échec")"
echo "- Migration appliquée à la base de test: $([ $test_result -eq 0 ] && echo "Succès" || echo "Non appliquée/Échec")"

# Si tout s'est bien passé
if [ $normal_result -eq 0 ] && [ $test_result -eq 0 ]; then
    exit 0
else
    exit 1
fi
