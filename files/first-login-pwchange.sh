#!/bin/bash
FLAG_FILE="$HOME/.config/.pwchanged"

if [ -f "$FLAG_FILE" ]; then
    exit 0
fi

if ! id "$USER" | grep -q "ipa"; then
    exit 0
fi

TMPSCRIPT=$(mktemp /tmp/pwchange_XXXXXX.sh)
cat > "$TMPSCRIPT" << 'ENDSCRIPT'
#!/bin/bash
trap '' INT TERM HUP

while true; do

    OLD_PASS=$(zenity --password \
        --title="Changement de mot de passe obligatoire" \
        --text="Bienvenue <b>$USER</b>.\n\nSaisissez votre <b>mot de passe actuel</b> :" \
        2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$OLD_PASS" ]; then
        zenity --warning \
            --title="Étape obligatoire" \
            --text="Cette étape est obligatoire.\nVous ne pouvez pas ignorer le changement de mot de passe." \
            --no-wrap 2>/dev/null
        continue
    fi

    NEW_PASS=$(zenity --password \
        --title="Changement de mot de passe obligatoire" \
        --text="Saisissez votre <b>nouveau mot de passe</b> :" \
        2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$NEW_PASS" ]; then
        continue
    fi

    CONFIRM_PASS=$(zenity --password \
        --title="Changement de mot de passe obligatoire" \
        --text="<b>Confirmez</b> votre nouveau mot de passe :" \
        2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$CONFIRM_PASS" ]; then
        continue
    fi

    if [ "$NEW_PASS" != "$CONFIRM_PASS" ]; then
        zenity --error \
            --title="Erreur" \
            --text="Les mots de passe ne correspondent pas.\nVeuillez réessayer." \
            --no-wrap 2>/dev/null
        continue
    fi

    RESULT=$(expect -c "
        log_user 0
        spawn passwd
        expect -re {[Aa]ctuel|[Cc]urrent|UNIX} { send \"$OLD_PASS\r\" }
        expect -re {[Nn]ouveau|[Nn]ew} { send \"$NEW_PASS\r\" }
        expect -re {[Rr]etap|[Rr]etype|[Cc]onfirm} { send \"$NEW_PASS\r\" }
        expect eof
        catch wait result
        exit [lindex \$result 3]
    " 2>&1)

    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        mkdir -p ~/.config
        touch ~/.config/.pwchanged
        rm -f ~/.config/autostart/first-login-pwchange.desktop
        echo "$(date) - $USER : succès" >> /var/log/first-login-pwchange.log
        zenity --info \
            --title="Mot de passe mis à jour" \
            --text="✓ Votre mot de passe a été défini avec succès.\n\nBienvenue sur votre poste de travail." \
            --no-wrap 2>/dev/null
        break
    else
        zenity --error \
            --title="Échec du changement" \
            --text="Le mot de passe n'a pas pu être modifié.\n\nVérifiez :\n• Mot de passe actuel correct\n• 8 caractères minimum\n• Majuscules, minuscules, chiffres\n• Différent de l'ancien" \
            --no-wrap 2>/dev/null
    fi

done
rm -f "$0"
ENDSCRIPT

chmod +x "$TMPSCRIPT"
io.elementary.terminal -x "$TMPSCRIPT"
