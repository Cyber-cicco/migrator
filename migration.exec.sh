#!/bin/bash

# Script de migration de base de données
# Usage: ./migrate.sh [numéro_départ|hash-commit_départ] [numéro_fin|hash-commit_fin]

# Use environment variables if set, otherwise use defaults
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASS:-}"
DB_NAME="${DB_NAME:-example}"
MIGRATION_DIR="./migration"

# Vérifier que le répertoire de migration existe
if [ ! -d "$MIGRATION_DIR" ]; then
    echo "Erreur: Le répertoire $MIGRATION_DIR n'existe pas."
    exit 1
fi

# Fonction pour obtenir l'index du fichier de migration
get_file_index() {
    local target=$1
    local index=-1
    local all_files=($(ls "$MIGRATION_DIR"/*.sql | sort))
    local i=0
    
    if [[ "$target" =~ ^[0-9]+$ ]]; then
        # Si la cible est un nombre, chercher le fichier avec ce numéro
        for file in "${all_files[@]}"; do
            file_num=$(basename "$file" | cut -d'-' -f1)
            if [ "$file_num" -eq "$target" ]; then
                index=$i
                break
            fi
            ((i++))
        done
    else
        # Si la cible est un hash de commit
        for file in "${all_files[@]}"; do
            file_hash=$(basename "$file" | cut -d'-' -f2 | cut -d'.' -f1)
            if [[ "$file_hash" == "$target" ]]; then
                index=$i
                break
            fi
            ((i++))
        done
    fi
    
    echo $index
}

# Fonction pour appliquer les migrations entre deux fichiers spécifiques
apply_migrations() {
    local start_target=$1
    local end_target=$2
    local all_files=($(ls "$MIGRATION_DIR"/*.sql | sort))
    
    # Si aucun end_target n'est spécifié, on prend tous les fichiers depuis start_target
    if [ -z "$end_target" ]; then
        if [[ "$start_target" =~ ^[0-9]+$ ]]; then
            # Si start_target est un numéro, on commence à partir de ce numéro
            local start_index=$(get_file_index "$start_target")
            if [ $start_index -eq -1 ]; then
                echo "Erreur: Aucun fichier de migration avec le numéro $start_target trouvé."
                exit 1
            fi
            local files_to_apply=("${all_files[@]:$start_index}")
        else
            # Si start_target est un hash, on commence à partir de ce hash
            local start_index=$(get_file_index "$start_target")
            if [ $start_index -eq -1 ]; then
                echo "Erreur: Aucun fichier de migration avec le hash $start_target trouvé."
                exit 1
            fi
            local files_to_apply=("${all_files[@]:$start_index}")
        fi
    else
        # Si end_target est spécifié, on prend les fichiers entre start_target et end_target
        local start_index=$(get_file_index "$start_target")
        local end_index=$(get_file_index "$end_target")
        
        if [ $start_index -eq -1 ]; then
            echo "Erreur: Aucun fichier de migration correspondant à $start_target trouvé."
            exit 1
        fi
        
        if [ $end_index -eq -1 ]; then
            echo "Erreur: Aucun fichier de migration correspondant à $end_target trouvé."
            exit 1
        fi
        
        if [ $start_index -gt $end_index ]; then
            echo "Erreur: Le numéro/hash de départ ($start_target) est supérieur au numéro/hash de fin ($end_target)."
            exit 1
        fi
        
        local files_to_apply=("${all_files[@]:$start_index:$((end_index-start_index+1))}")
    fi
    
    # Vérifier qu'on a trouvé des fichiers à appliquer
    if [ ${#files_to_apply[@]} -eq 0 ]; then
        echo "Aucun fichier de migration correspondant trouvé."
        exit 1
    fi
    
    # Créer un fichier temporaire pour les migrations
    local temp_file=$(mktemp)
    
    # Concaténer les fichiers SQL
    echo "Fichiers à appliquer:"
    for file in "${files_to_apply[@]}"; do
        echo " - $(basename "$file")"
        cat "$file" >> "$temp_file"
        echo "" >> "$temp_file"  # Ajouter une ligne vide entre les fichiers
    done
    
    # Construire la chaîne de connexion
    local connection_params="-h $DB_HOST -p $DB_PORT -U $DB_USER"
    
    # Ajouter le paramètre de mot de passe si défini
    if [ -n "$DB_PASSWORD" ]; then
        export PGPASSWORD="$DB_PASSWORD"
    fi
    
    # Appliquer les migrations
    echo "Application des migrations à la base de données $DB_NAME..."
    if psql $connection_params -d "$DB_NAME" -f "$temp_file"; then
        echo "Migration réussie!"
    else
        echo "Erreur lors de la migration."
        rm "$temp_file"
        [ -n "$DB_PASSWORD" ] && unset PGPASSWORD
        exit 1
    fi
    
    # Nettoyer
    rm "$temp_file"
    [ -n "$DB_PASSWORD" ] && unset PGPASSWORD
}

# Afficher l'aide si aucun argument n'est fourni
if [ $# -eq 0 ]; then
    echo "Usage: $0 [numéro_départ|hash-commit_départ] [numéro_fin|hash-commit_fin]"
    echo ""
    echo "Arguments:"
    echo "  numéro_départ|hash-commit_départ - Point de départ de la migration"
    echo "  numéro_fin|hash-commit_fin      - Point d'arrivée de la migration (optionnel)"
    echo ""
    echo "Exemples:"
    echo "  $0 0001            - Applique la migration 0001 et toutes les suivantes"
    echo "  $0 0001 0005       - Applique les migrations de 0001 à 0005 inclus"
    echo "  $0 abc123          - Applique la migration avec le hash abc123 et toutes les suivantes"
    echo "  $0 abc123 def456   - Applique les migrations du hash abc123 au hash def456 inclus"
    echo ""
    echo "Fichiers de migration disponibles:"
    ls -1 "$MIGRATION_DIR"/*.sql 2>/dev/null | sort | sed 's/.*\//  /'
    exit 0
fi

# Appliquer les migrations
if [ $# -eq 1 ]; then
    apply_migrations "$1"
elif [ $# -eq 2 ]; then
    apply_migrations "$1" "$2"
else
    echo "Erreur: Trop d'arguments fournis."
    echo "Usage: $0 [numéro_départ|hash-commit_départ] [numéro_fin|hash-commit_fin]"
    exit 1
fi
