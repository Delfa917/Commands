#!/bin/bash

# Lire le fichier CSV
while IFS="," read -r matricule prenom nom naissance groupe reste
do
    # Vérifier si le groupe existe
    if ! grep -q "^$groupe:" /etc/group
    then
        groupadd "$groupe"
    fi

    # Vérifier si l'utilisateur existe
    if ! id "$matricule" > /dev/null 2>&1
    then
        useradd -m -g "$groupe" "$matricule"
        echo "Utilisateur $matricule créé"
    else
        echo "Utilisateur $matricule déjà existant"
    fi

done < "$1"


//TEST PROGRAMME PLUS SPECIFIQUE (ENTIEREMENT IA)


#!/bin/bash

# Vérifier que le script est lancé avec sudo
if [ "$EUID" -ne 0 ]
then
    echo "Erreur : utilisez sudo"
    exit 1
fi

# Vérifier le fichier CSV
if [ ! -f "$1" ]
then
    echo "Fichier CSV introuvable"
    exit 1
fi

# Lire le fichier CSV
while IFS="," read -r matricule prenom nom naissance pole service poste projets reste
do

    # Ignorer la première ligne
    if [ "$matricule" = "Matricule" ]
    then
        continue
    fi

    # Créer le login : première lettre du prénom + nom
    login="${prenom:0:1}$nom"

    # Supprimer les accents et les caractères spéciaux
    login=$(echo "$login" | iconv -f UTF-8 -t ASCII//TRANSLIT)
    login=$(echo "$login" | tr 'A-Z' 'a-z')
    login=$(echo "$login" | tr -cd 'a-z')

    # Limiter à 8 caractères
    login="${login:0:8}"

    if [ -z "$login" ]
    then
        echo "Login invalide pour $matricule"
        continue
    fi

    # Créer le groupe principal à partir du pôle
    pole=$(echo "$pole" | tr 'A-Z' 'a-z')

    if [[ ! "$pole" =~ ^[a-z_][a-z0-9_-]*$ ]]
    then
        echo "Pôle invalide : $pole"
        continue
    fi

    if ! grep -q "^$pole:" /etc/group
    then
        if ! groupadd "$pole"
        then
            echo "Erreur de création du groupe $pole"
            continue
        fi
    fi

    # Créer l'utilisateur dans son groupe principal
    if ! id "$login" > /dev/null 2>&1
    then
        if useradd -m -g "$pole" -s /bin/bash -c "$matricule" "$login"
        then
            echo "Utilisateur $login créé dans $pole"
        else
            echo "Erreur de création : $login"
            continue
        fi

        # Définir un mot de passe initial
        mdp=$(echo "$naissance" | tr -d '/')

        if echo "$login:$mdp" | chpasswd
        then
            # Demander de changer le mot de passe
            chage -d 0 "$login"
        else
            echo "Erreur de mot de passe pour $login"
            passwd -l "$login"
        fi
    else
        echo "Utilisateur $login déjà existant"
    fi

    # Créer les groupes secondaires des projets
    for projet in $(echo "$projets" | tr ';' ' ')
    do
        projet=$(echo "$projet" | iconv -f UTF-8 -t ASCII//TRANSLIT)
        projet=$(echo "$projet" | tr 'A-Z' 'a-z')

        if [[ ! "$projet" =~ ^[a-z_][a-z0-9_-]*$ ]]
        then
            echo "Projet invalide : $projet"
            continue
        fi

        # Créer le groupe du projet
        if ! grep -q "^$projet:" /etc/group
        then
            if ! groupadd "$projet"
            then
                echo "Erreur de création : $projet"
                continue
            fi
        fi

        # Ajouter l'utilisateur au groupe du projet
        if usermod -aG "$projet" "$login"
        then
            echo "$login ajouté à $projet"
        fi

    done

done < "$1"

echo "Création des comptes terminée"
