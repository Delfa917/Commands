#!/bin/bash

# Lancer avec sudo ./createusers.sh tekitizy_users.csv
if [ "$EUID" -ne 0 ] || [ ! -f "$1" ]; then
    echo "Utilisation : sudo $0 fichier.csv"
    exit 1
fi

# Le groupe commun et les dossiers de base
getent group personnel > /dev/null || groupadd personnel
mkdir -p /SERVICES/COMMUN /PROJETS
chown root:personnel /SERVICES/COMMUN
chmod 2770 /SERVICES/COMMUN

# Lire chaque salarié en ignorant la ligne de titre
{
read -r entete
while IFS=',' read -r matricule prenom nom naissance pole service poste projets reste
do
    # Nom du compte 
    login="${prenom:0:1}$nom"
    login=$(echo "$login" | iconv -f UTF-8 -t ASCII//TRANSLIT | tr 'A-Z' 'a-z' | tr -cd 'a-z')
    login="${login:0:8}"
    if [ -z "$login" ]; then
        echo "Nom invalide pour $matricule"
        continue
    fi

    # Rajouter chiffe si login existant
    base="${login:0:6}"
    numero=1
    while id "$login" > /dev/null 2>&1
    do
        login="$base$(printf '%02d' "$numero")"
        numero=$((numero + 1))
        if [ "$numero" -gt 99 ]; then
            echo "Trop de doublons : $matricule"
            break
        fi
    done
    if [ "$numero" -gt 99 ]; then continue; fi

    # Nommage des dossiers et groupe
    pole_dossier=$(echo "$pole" | iconv -f UTF-8 -t ASCII//TRANSLIT | tr 'a-z' 'A-Z' | tr -cd 'A-Z_')
    pole_groupe=$(echo "$pole_dossier" | tr 'A-Z' 'a-z')
    if [ -z "$pole_groupe" ]; then continue; fi

    getent group "$pole_groupe" > /dev/null || groupadd "$pole_groupe"
    mkdir -p "/SERVICES/$pole_dossier"
    chown "root:$pole_groupe" "/SERVICES/$pole_dossier"
    chmod 2770 "/SERVICES/$pole_dossier"

    # Créer le compte
    if ! useradd -m -g "$pole_groupe" -G personnel -s /bin/bash -c "$matricule" "$login"; then
        echo "Erreur pour $matricule"
        continue
    fi
    chmod 700 "/home/$login"

    # Mot de passe initial en format JJMMYYYY
    mdp=$(echo "$naissance" | tr -d '/')
    if [[ "$mdp" =~ ^[0-9]{8}$ ]]; then
        if echo "$login:$mdp" | chpasswd; then
            chage -d 0 "$login"
        else
            passwd -l "$login"
        fi
    else
        echo "Date invalide : mot de passe verrouillé pour $login"
        passwd -l "$login"
    fi

    # Dossiers personnels
    mkdir -p "/home/$login/Documents" "/home/$login/Workspace" "/home/$login/Téléchargements"
    mkdir -p "/home/$login/Projets" "/home/$login/Partage"
    chown -R "$login:$pole_groupe" "/home/$login"
    ln -s "/SERVICES/$pole_dossier" "/home/$login/Partage/$pole_dossier"
    ln -s /SERVICES/COMMUN "/home/$login/Partage/COMMUN"

    # Sous-service facultatif
    if [ -n "$service" ]; then
        service_dossier=$(echo "$service" | iconv -f UTF-8 -t ASCII//TRANSLIT | tr -cd 'A-Za-z_' )
        service_groupe=$(echo "$service_dossier" | tr 'A-Z' 'a-z')
        if [ -n "$service_groupe" ]; then
            getent group "$service_groupe" > /dev/null || groupadd "$service_groupe"
            usermod -aG "$service_groupe" "$login"
            mkdir -p "/SERVICES/$pole_dossier/$service_dossier"
            chown "root:$service_groupe" "/SERVICES/$pole_dossier/$service_dossier"
            chmod 2770 "/SERVICES/$pole_dossier/$service_dossier"
            ln -s "/SERVICES/$pole_dossier/$service_dossier" "/home/$login/Partage/$service_dossier"
        fi
    fi

    # Projets séparés par des ;
    for projet in $(echo "$projets" | tr ';' ' ')
    do
        projet_dossier=$(echo "$projet" | iconv -f UTF-8 -t ASCII//TRANSLIT | tr 'a-z' 'A-Z' | tr -cd 'A-Z_')
        projet_groupe=$(echo "$projet_dossier" | tr 'A-Z' 'a-z')
        if [ -z "$projet_groupe" ]; then continue; fi
        getent group "$projet_groupe" > /dev/null || groupadd "$projet_groupe"
        usermod -aG "$projet_groupe" "$login"
        mkdir -p "/PROJETS/$projet_dossier"
        chown "root:$projet_groupe" "/PROJETS/$projet_dossier"
        chmod 2770 "/PROJETS/$projet_dossier"
        ln -s "/PROJETS/$projet_dossier" "/home/$login/Projets/$projet_dossier"
    done
    echo "Compte créé : $login ($matricule)"
done
} < "$1"

echo "Installation terminée"
