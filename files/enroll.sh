#!/bin/bash
# enroll.sh - Auto-enrôlement d'un poste GCA Formation
# Exécuter avec : sudo bash enroll.sh

AWX_URL="https://10.52.161.85:32386"
AWX_TOKEN="VOTRE_TOKEN_AWX"
INVENTORY_ID="2"
TEMPLATE_JONCTION="9"
TEMPLATE_LIBREOFFICE="12"
TEMPLATE_NEXTCLOUD="13"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   GRETA-CFA Aquitaine - Enrôlement du poste   ${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Vérifier les droits root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Ce script doit être exécuté avec sudo.${NC}"
    echo "Usage : sudo bash enroll.sh"
    exit 1
fi

# Vérifier et installer les prérequis
echo -e "${YELLOW}[1/6] Vérification des prérequis...${NC}"

if ! command -v curl &>/dev/null; then
    echo "  Installation de curl..."
    apt install -y curl &>/dev/null
fi

if ! command -v python3 &>/dev/null; then
    echo "  Installation de python3..."
    apt install -y python3 &>/dev/null
fi

if ! command -v zenity &>/dev/null; then
    echo "  Installation de zenity..."
    apt install -y zenity &>/dev/null
fi

if ! systemctl is-active --quiet ssh; then
    echo "  Installation et démarrage de openssh-server..."
    apt install -y openssh-server &>/dev/null
    systemctl enable ssh &>/dev/null
    systemctl start ssh &>/dev/null
fi

echo -e "  ${GREEN}Prérequis OK${NC}"

# Demander le hostname via fenêtre graphique
echo -e "${YELLOW}[2/6] Configuration du nom du poste...${NC}"

CURRENT_HOSTNAME=$(hostname)
NEW_HOSTNAME=$(zenity --entry \
    --title="GRETA-CFA - Enrôlement du poste" \
    --text="Entrez le nom du poste :\n(Format recommandé : PC-SALLE-NUMERO, ex: PC-101-01)" \
    --entry-text="$CURRENT_HOSTNAME" \
    2>/dev/null)

if [ -z "$NEW_HOSTNAME" ]; then
    echo -e "${RED}Annulé par l'utilisateur.${NC}"
    exit 1
fi

# Appliquer le nouveau hostname
hostnamectl set-hostname "$NEW_HOSTNAME"
echo "  Nouveau nom : $NEW_HOSTNAME"
echo -e "  ${GREEN}Hostname configuré${NC}"

# Récupérer l'IP
IP=$(hostname -I | awk '{print $1}')
echo ""
echo -e "  Poste : ${GREEN}$NEW_HOSTNAME${NC} ($IP)"

# Vérifier la connectivité AWX
echo ""
echo -e "${YELLOW}[3/6] Connexion à AWX...${NC}"
PING=$(curl -sk "$AWX_URL/api/v2/ping/" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('version',''))" 2>/dev/null)
if [ -z "$PING" ]; then
    zenity --error --title="Erreur" --text="Impossible de joindre le serveur AWX.\nVérifiez la connexion réseau." 2>/dev/null
    exit 1
fi
echo -e "  ${GREEN}AWX $PING accessible${NC}"

# Enregistrer dans l'inventaire AWX
echo ""
echo -e "${YELLOW}[4/6] Enregistrement dans l'inventaire...${NC}"
HOST_RESULT=$(curl -sk -X POST \
    -H "Authorization: Bearer $AWX_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"$NEW_HOSTNAME\", \"inventory\": $INVENTORY_ID, \"variables\": \"ansible_host: $IP\"}" \
    "$AWX_URL/api/v2/hosts/")

HOST_ID=$(echo $HOST_RESULT | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null)
if [ -z "$HOST_ID" ]; then
    echo -e "  ${YELLOW}Poste déjà enregistré ou mise à jour de l'IP...${NC}"
else
    echo -e "  ${GREEN}Poste enregistré (ID: $HOST_ID)${NC}"
fi

# Fonction pour lancer un job et attendre le résultat
run_job() {
    local TEMPLATE_ID=$1
    local JOB_NAME=$2

    JOB_RESULT=$(curl -sk -X POST \
        -H "Authorization: Bearer $AWX_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"limit\": \"$NEW_HOSTNAME\"}" \
        "$AWX_URL/api/v2/job_templates/$TEMPLATE_ID/launch/")

    JOB_ID=$(echo $JOB_RESULT | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null)

    if [ -z "$JOB_ID" ]; then
        echo -e "  ${RED}Échec du lancement de $JOB_NAME${NC}"
        return 1
    fi

    echo -n "  En cours"
    while true; do
        STATUS=$(curl -sk \
            -H "Authorization: Bearer $AWX_TOKEN" \
            "$AWX_URL/api/v2/jobs/$JOB_ID/" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status',''))" 2>/dev/null)

        if [ "$STATUS" = "successful" ]; then
            echo -e " ${GREEN}✓${NC}"
            return 0
        elif [ "$STATUS" = "failed" ] || [ "$STATUS" = "error" ]; then
            echo -e " ${RED}✗${NC}"
            return 1
        else
            echo -n "."
            sleep 5
        fi
    done
}

# Lancer les jobs dans l'ordre
echo ""
echo -e "${YELLOW}[5/6] Déploiement de la configuration...${NC}"
echo ""

echo -n "  Jonction au domaine FreeIPA... "
run_job $TEMPLATE_JONCTION "Jonction FreeIPA"

echo -n "  Installation LibreOffice... "
run_job $TEMPLATE_LIBREOFFICE "LibreOffice"

echo -n "  Installation client Nextcloud... "
run_job $TEMPLATE_NEXTCLOUD "Nextcloud"

# Résultat final
echo ""
echo -e "${YELLOW}[6/6] Finalisation...${NC}"
echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}   Enrôlement terminé avec succès !             ${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

zenity --info \
    --title="Enrôlement terminé" \
    --text="✓ Le poste <b>$NEW_HOSTNAME</b> est intégré à l'infrastructure.\n\nUn redémarrage est nécessaire pour finaliser la configuration." \
    2>/dev/null

# Proposer le redémarrage
zenity --question \
    --title="Redémarrage" \
    --text="Voulez-vous redémarrer maintenant ?" \
    2>/dev/null && reboot
