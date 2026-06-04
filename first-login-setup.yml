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
    echo "✗ Échec. Nouvelle tentative à la prochaine connexion."
    sleep 5
fi
rm -f "$0"
ENDSCRIPT

chmod +x "$TMPSCRIPT"
io.elementary.terminal -x "$TMPSCRIPT"
