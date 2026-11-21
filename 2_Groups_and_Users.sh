#!/bin/bash
# SCRIPT DE CRÉATION AUTOMATIQUE D'UTILISATEURS ET GROUPES DEPUIS UN CSV

# 1. Vérifier que le script est lancé avec sudo
if [ "$EUID" -ne 0 ]
then
    echo "Erreur : utilisez sudo pour lancer ce script."
    exit 1
fi

# 2. Vérifier que le fichier CSV existe
if [ ! -f "$1" ]
then
    echo "Erreur : Fichier CSV introuvable."
    exit 1
fi

# 3. Lire le fichier CSV
while IFS="," read -r matricule prenom nom naissance pole service poste projets reste
do

    # Ignorer les en-têtes de colonnes
    if [ "$matricule" = "Matricule" ]
    then
        continue
    fi

    # --- ÉTAPE A : GÉNÉRATION DU LOGIN ---
    # Première lettre du prénom + nom de famille
    login="${prenom:0:1}$nom"

    # Suppression des accents, des caractères spéciaux et passage en minuscules 
    login=$(echo "$login" | iconv -f UTF-8 -t ASCII//TRANSLIT)
    login=$(echo "$login" | tr 'A-Z' 'a-z')
    login=$(echo "$login" | tr -cd 'a-z')

    # Limiter le login à 8 charactères
    login="${login:0:8}"

    if [ -z "$login" ]
    then
        echo "Login invalide pour le matricule : $matricule"
        continue
    fi

    # --- ÉTAPE B : GROUPE PRINCIPAL ---
    pole=$(echo "$pole" | iconv -f UTF-8 -t ASCII//TRANSLIT)
    pole=$(echo "$pole" | tr 'A-Z' 'a-z')

    if [[ ! "$pole" =~ ^[a-z_][a-z0-9_-]*$ ]]
    then
        echo "Nom de pôle invalide : $pole"
        continue
    fi

    if ! grep -q "^$pole:" /etc/group
    then
        if ! groupadd "$pole"
        then
            echo "Erreur lors de la création du groupe : $pole"
            continue
        fi
    fi

    # --- ÉTAPE C : GROUPE SECONDAIRE ---
    service=$(echo "$service" | iconv -f UTF-8 -t ASCII//TRANSLIT)
    service=$(echo "$service" | tr 'A-Z' 'a-z')

    # Nommage combiné (ex: informatique_reseau)
    groupe_service="${pole}_${service}"

    if [[ ! "$groupe_service" =~ ^[a-z_][a-z0-9_-]*$ ]]
    then
        echo "Nom de sous-service invalide : $service"
        continue
    fi

    if ! grep -q "^$groupe_service:" /etc/group
    then
        if ! groupadd "$groupe_service"
        then
            echo "Erreur lors de la création du groupe secondaire : $groupe_service"
            continue
        fi
    fi

    # --- ÉTAPE D : CRÉATION DE L'UTILISATEUR ---
    if ! id "$login" > /dev/null 2>&1
    then
        if useradd -m -g "$pole" -s /bin/bash -c "$matricule" "$login"
        then
            echo "Utilisateur $login créé dans le pôle $pole"
        else
            echo "Erreur : Impossible de créer l'utilisateur : $login"
            continue
        fi

        # Définition du mot de passe initial (date de naissance)
        mdp=$(echo "$naissance" | tr -d '/')

        if echo "$login:$mdp" | chpasswd
        then
            # Oblige l'utilisateur à changer son mot de passe à la 1ère connexion
            chage -d 0 "$login"
        else
            echo "Erreur : Problème de mot de passe pour $login (compte verrouillé)"
            passwd -l "$login"
        fi
    else
        echo "L'utilisateur $login existe déjà"
    fi

    # Rattachement au groupe du sous-service
    if usermod -aG "$groupe_service" "$login"
    then
        echo "  -> $login ajouté au sous-service : $groupe_service"
    fi

    # --- ÉTAPE E : GROUPES SECONDAIRES (PROJETS) ---
    for projet in $(echo "$projets" | tr ';' ' ')
    do
        projet=$(echo "$projet" | iconv -f UTF-8 -t ASCII//TRANSLIT)
        projet=$(echo "$projet" | tr 'A-Z' 'a-z')

        if [[ ! "$projet" =~ ^[a-z_][a-z0-9_-]*$ ]]
        then
            echo "Nom de projet invalide : $projet"
            continue
        fi

        if ! grep -q "^$projet:" /etc/group
        then
            if ! groupadd "$projet"
            then
                echo "Erreur lors de la création du projet : $projet"
                continue
            fi
        fi

        if usermod -aG "$projet" "$login"
        then
            echo "  -> $login ajouté au projet : $projet"
        fi
    done

done < "$1"

echo "Création des comptes terminée."
