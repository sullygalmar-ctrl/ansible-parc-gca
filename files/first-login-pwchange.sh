#!/bin/bash
# first-login-pwchange.sh
# Déclenché au premier login d'un compte FreeIPA

FLAG_FILE="$HOME/.config/.pwchanged"

# Si déjà fait, on quitte silencieusement
if [ -f "$FLAG_FILE" ]; then
    exit 0
fi

# Uniquement pour les comptes du domaine IPA
if ! id "$USER" | grep -q "ipa"; then
    exit 0
fi

# Ouvre un terminal avec le dialogue de changement de mot de passe
x-terminal-emulator -T "Changement de mot de passe obligatoire" \
    -e bash -c '
        clear
        echo "============================================"
        echo "  Bienvenue sur votre poste de travail."
        echo "  Vous devez définir votre mot de passe."
        echo "============================================"
        echo ""
        passwd
        STATUS=$?
        if [ $STATUS -eq 0 ]; then
            mkdir -p ~/.config
            touch ~/.config/.pwchanged
            echo "$(date) - $USER : succès" >> /var/log/first-login-pwchange.log
            echo ""
            echo "✓ Mot de passe mis à jour. Fermeture dans 3 secondes..."
            sleep 3
        elif [ $STATUS -eq 10 ]; then
            echo ""
            echo "⚠ Mot de passe changé trop récemment."
            echo "  Contactez votre administrateur."
            sleep 6
        else
            echo ""
            echo "✗ Échec (code $STATUS). Nouvelle tentative à la prochaine connexion."
            sleep 5
        fi
    '
