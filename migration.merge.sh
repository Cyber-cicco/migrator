#!/bin/bash
# Script pour fusionner les fichiers de migration en attente en un seul fichier
# Usage: ./merge_migrations.sh

# Use environment variables if set, otherwise use defaults
PENDING_DIR="./pending_migration"
MIGRATION_DIR="./migration"

# Vérifier que les répertoires existent
if [ ! -d "$PENDING_DIR" ]; then
    echo "Erreur: Le répertoire $PENDING_DIR n'existe pas."
    exit 1
fi

if [ ! -d "$MIGRATION_DIR" ]; then
    echo "Erreur: Le répertoire $MIGRATION_DIR n'existe pas."
    echo "Création du répertoire..."
    mkdir -p "$MIGRATION_DIR"
fi

# Vérifier qu'on est dans un dépôt git
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Erreur: Ce n'est pas un dépôt git."
    exit 1
fi

# Récupérer le hash du commit actuel (7 premiers caractères)
COMMIT_HASH=$(git rev-parse --short HEAD)
if [ $? -ne 0 ]; then
    echo "Erreur: Impossible de récupérer le hash du commit actuel."
    exit 1
fi

# Trouver le numéro de la dernière migration
LAST_NUMBER=0
if [ "$(ls -A $MIGRATION_DIR 2>/dev/null)" ]; then
    LAST_NUMBER=$(ls -1 $MIGRATION_DIR/*.sql 2>/dev/null | sed 's/.*\/\([0-9]\+\).*/\1/' | sort -n | tail -1)
fi

# Calculer le nouveau numéro (avec padding à 4 chiffres)
NEXT_NUMBER=$(printf "%04d" $((10#$LAST_NUMBER + 1)))
NEW_MIGRATION_FILE="$MIGRATION_DIR/$NEXT_NUMBER-$COMMIT_HASH.sql"

# Créer le fichier de migration fusionné avec un en-tête
echo "-- Migration fusionnée $NEXT_NUMBER-$COMMIT_HASH" > "$NEW_MIGRATION_FILE"
echo "-- Date: $(date '+%Y-%m-%d %H:%M:%S')" >> "$NEW_MIGRATION_FILE"
echo "-- Contient les migrations suivantes:" >> "$NEW_MIGRATION_FILE"


# Vérifier s'il y a des fichiers en attente
if [ ! "$(ls -A $PENDING_DIR/*.sql 2>/dev/null)" ]; then
    echo "Aucun fichier de migration en attente trouvé dans $PENDING_DIR."
    touch $NEW_MIGRATION_FILE
    echo "Création d'un fichier vide pour l'historisation"
    exit 0
fi

# Lister les fichiers en attente par ordre numérique
PENDING_FILES=$(ls -1v $PENDING_DIR/*.sql 2>/dev/null)

# Ajouter chaque migration en attente au fichier fusionné
for file in $PENDING_FILES; do
    filename=$(basename "$file")
    echo "-- * $filename" >> "$NEW_MIGRATION_FILE"
done

echo "" >> "$NEW_MIGRATION_FILE"
echo "BEGIN;" >> "$NEW_MIGRATION_FILE"
echo "" >> "$NEW_MIGRATION_FILE"

# Fusionner le contenu de chaque fichier
for file in $PENDING_FILES; do
    filename=$(basename "$file")
    echo "-- Début de la migration: $filename" >> "$NEW_MIGRATION_FILE"
    echo "" >> "$NEW_MIGRATION_FILE"
    cat "$file" >> "$NEW_MIGRATION_FILE"
    echo "" >> "$NEW_MIGRATION_FILE"
    echo "-- Fin de la migration: $filename" >> "$NEW_MIGRATION_FILE"
    echo "" >> "$NEW_MIGRATION_FILE"
done

echo "COMMIT;" >> "$NEW_MIGRATION_FILE"

echo "Les migrations ont été fusionnées avec succès dans le fichier: $NEW_MIGRATION_FILE"

# Demander à l'utilisateur s'il souhaite supprimer les fichiers en attente
read -p "Voulez-vous supprimer les fichiers de migration en attente? (o/n): " delete_pending

if [ "$delete_pending" = "o" ] || [ "$delete_pending" = "O" ]; then
    rm $PENDING_DIR/*.sql
    echo "Les fichiers de migration en attente ont été supprimés."
else
    echo "Les fichiers de migration en attente ont été conservés."
fi

exit 0
