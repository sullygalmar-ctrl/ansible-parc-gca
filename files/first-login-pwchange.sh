#!/bin/bash
FLAG_FILE="$HOME/.config/.pwchanged"

if [ -f "$FLAG_FILE" ]; then
    exit 0
fi

if ! id "$USER" | grep -q "ipa"; then
    exit 0
fi

# Boucle jusqu'au succès
while true; do

    # Saisie du nouveau mot de passe
    NEW_PASS=$(zenity --password \
        --title="🔒 Changement de mot de passe obligatoire" \
        --text="Bienvenue <b>$USER</b>.\n\nVeuillez définir votre nouveau mot de passe pour accéder à votre poste de travail." \
        2>/dev/null)

    # Si l'utilisateur ferme la fenêtre → on relance
    if [ $? -ne 0 ] || [ -z "$NEW_PASS" ]; then
        zenity --warning \
            --title="Changement de mot de passe obligatoire" \
            --text="Vous devez définir votre mot de passe pour continuer.\n\nCette étape est obligatoire." \
            --no-wrap \
            2>/dev/null
        continue
    fi

    # Confirmation du mot de passe
    CONFIRM_PASS=$(zenity --password \
        --title="🔒 Confirmation du mot de passe" \
        --text="Confirmez votre nouveau mot de passe." \
        2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$CONFIRM_PASS" ]; then
        continue
    fi

    # Vérification correspondance
    if [ "$NEW_PASS" != "$CONFIRM_PASS" ]; then
        zenity --error \
            --title="Erreur" \
            --text="Les mots de passe ne correspondent pas.\nVeuillez réessayer." \
            --no-wrap \
            2>/dev/null
        continue
    fi

    # Envoi à passwd via expect
    RESULT=$(expect -c "
        spawn passwd
        expect \"Mot de passe actuel\" { send \"$NEW_PASS\r\" }
        expect \"Nouveau mot de passe\" { send \"$NEW_PASS\r\" }
        expect \"Retapez\" { send \"$NEW_PASS\r\" }
        expect eof
    " 2>&1)

    if echo "$RESULT" | grep -q "succès\|successfully\|updated"; then
        mkdir -p ~/.config
        touch ~/.config/.pwchanged
        echo "$(date) - $USER : succès" >> /var/log/first-login-pwchange.log
        zenity --info \
            --title="✓ Mot de passe mis à jour" \
            --text="Votre mot de passe a été défini avec succès.\n\nBienvenue sur votre poste de travail." \
            --no-wrap \
            2>/dev/null
        break
    else
        zenity --error \
            --title="Échec" \
            --text="Le mot de passe n'a pas pu être modifié.\n\nAssurez-vous de respecter la politique de sécurité :\n- 8 caractères minimum\n- Majuscules, minuscules, chiffres" \
            --no-wrap \
            2>/dev/null
    fi

done
