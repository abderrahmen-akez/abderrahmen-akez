#!/usr/bin/env bash
# =============================================================
#  TEK-UP University - ING-5-SSIR-S9-P5 - DevSecOps
#  Lab 1 - Verification de l'environnement / Environment check
#  Usage:  chmod +x verif_env.sh && ./verif_env.sh | tee rapport_env.txt
# =============================================================

GREEN='\033[0;32m'; RED='\033[0;31m'; YEL='\033[0;33m'; BOLD='\033[1m'; NC='\033[0m'
OK=0; KO=0

line()  { printf '%s\n' "-----------------------------------------------------------"; }
title() { printf "\n${BOLD}%s${NC}\n" "$1"; line; }

# check <label> <command> <expected-session>
check() {
  local label="$1" cmd="$2" needed="$3" ver bin
  bin=$(printf '%s' "$cmd" | awk '{print $1}')
  if command -v "$bin" >/dev/null 2>&1 && ver=$(eval "$cmd" 2>/dev/null | head -n1); then
    if [ -n "$ver" ]; then
      printf "  ${GREEN}[ OK ]${NC}  %-22s %s\n" "$label" "$ver"
      OK=$((OK+1)); return 0
    fi
  fi
  printf "  ${RED}[ABSENT]${NC} %-22s ${YEL}requis en seance %s${NC}\n" "$label" "$needed"
  KO=$((KO+1)); return 1
}

printf "${BOLD}"
echo "==========================================================="
echo "  RAPPORT DE VERIFICATION DE L'ENVIRONNEMENT DEVSECOPS"
echo "==========================================================="
printf "${NC}"
echo "  Etudiant  : $(whoami)"
echo "  Machine   : $(hostname)"
echo "  Date      : $(date '+%Y-%m-%d %H:%M:%S')"
echo "  Systeme   : $(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME")"
echo "  Noyau     : $(uname -r)"
echo "  Arch      : $(uname -m)"

title "1. RESSOURCES DE LA MACHINE"
CPU=$(nproc)
RAM=$(free -g | awk '/^Mem:/{print $2}')
DISK=$(df -BG --output=avail / | tail -1 | tr -dc '0-9')
printf "  %-22s %s coeurs\n" "Processeurs" "$CPU"
printf "  %-22s %s Go\n"     "Memoire vive" "$RAM"
printf "  %-22s %s Go libres\n" "Disque /" "$DISK"
[ "$CPU"  -ge 2 ] && printf "  ${GREEN}[ OK ]${NC}  CPU suffisant\n"   || { printf "  ${RED}[FAIBLE]${NC} 2 coeurs minimum\n"; KO=$((KO+1)); }
[ "$RAM"  -ge 3 ] && printf "  ${GREEN}[ OK ]${NC}  RAM suffisante\n"  || { printf "  ${RED}[FAIBLE]${NC} 4 Go minimum\n"; KO=$((KO+1)); }
[ "$DISK" -ge 15 ] && printf "  ${GREEN}[ OK ]${NC}  Disque suffisant\n" || { printf "  ${RED}[FAIBLE]${NC} 15 Go libres minimum\n"; KO=$((KO+1)); }

title "2. OUTILS DE BASE"
check "git"            "git --version"              "2"
check "curl"           "curl --version"             "2"
check "ssh"            "ssh -V 2>&1"                "2"

title "3. CONTENEURS"
check "docker"         "docker --version"           "3"
check "docker compose" "docker compose version"     "4"
if docker ps >/dev/null 2>&1; then
  printf "  ${GREEN}[ OK ]${NC}  %-22s le daemon repond sans sudo\n" "docker daemon"
  OK=$((OK+1))
else
  printf "  ${RED}[ERREUR]${NC} %-22s ${YEL}essayez: sudo usermod -aG docker \$USER puis newgrp docker${NC}\n" "docker daemon"
  KO=$((KO+1))
fi

title "4. LANGAGES ET BUILD"
check "java"           "java -version 2>&1"         "3"
check "maven"          "mvn -version"               "3"
check "node"           "node -v"                    "5"
check "npm"            "npm -v"                     "5"

title "5. KUBERNETES"
check "kubectl"        "kubectl version --client -o yaml 2>/dev/null | grep gitVersion" "12"
check "minikube"       "minikube version"           "12"

title "6. OUTILS DE SECURITE"
check "trivy"          "trivy --version"            "9"
check "gitleaks"       "gitleaks version"           "10"

title "7. CONFIGURATION GIT"
GN=$(git config --global user.name);  GE=$(git config --global user.email)
[ -n "$GN" ] && { printf "  ${GREEN}[ OK ]${NC}  %-22s %s\n" "git user.name" "$GN"; OK=$((OK+1)); } \
             || { printf "  ${RED}[ABSENT]${NC} %-22s ${YEL}git config --global user.name \"...\"${NC}\n" "git user.name"; KO=$((KO+1)); }
[ -n "$GE" ] && { printf "  ${GREEN}[ OK ]${NC}  %-22s %s\n" "git user.email" "$GE"; OK=$((OK+1)); } \
             || { printf "  ${RED}[ABSENT]${NC} %-22s ${YEL}git config --global user.email \"...\"${NC}\n" "git user.email"; KO=$((KO+1)); }
if [ -f "$HOME/.ssh/id_ed25519.pub" ] || [ -f "$HOME/.ssh/id_rsa.pub" ]; then
  printf "  ${GREEN}[ OK ]${NC}  %-22s presente\n" "cle SSH"; OK=$((OK+1))
else
  printf "  ${RED}[ABSENT]${NC} %-22s ${YEL}ssh-keygen -t ed25519 -C \"votre@email\"${NC}\n" "cle SSH"; KO=$((KO+1))
fi

title "8. ACCES RESEAU"
for host in gitlab.com registry-1.docker.io github.com; do
  if curl -sS -o /dev/null -m 8 "https://$host" 2>/dev/null; then
    printf "  ${GREEN}[ OK ]${NC}  %-22s joignable\n" "$host"; OK=$((OK+1))
  else
    printf "  ${RED}[ECHEC]${NC} %-22s ${YEL}verifiez le reseau / proxy${NC}\n" "$host"; KO=$((KO+1))
  fi
done
if ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -T git@gitlab.com 2>&1 | grep -qi "welcome"; then
  printf "  ${GREEN}[ OK ]${NC}  %-22s cle acceptee par GitLab\n" "ssh git@gitlab.com"; OK=$((OK+1))
else
  printf "  ${YEL}[A FAIRE]${NC} %-20s ${YEL}ajoutez votre cle publique dans GitLab > SSH Keys${NC}\n" "ssh git@gitlab.com"
  KO=$((KO+1))
fi

title "RESULTAT"
printf "  Controles reussis : ${GREEN}%s${NC}\n" "$OK"
printf "  Controles echoues : ${RED}%s${NC}\n" "$KO"
line
if [ "$KO" -eq 0 ]; then
  printf "${GREEN}${BOLD}  ENVIRONNEMENT COMPLET - vous etes pret pour la seance 2.${NC}\n\n"
  exit 0
else
  printf "${RED}${BOLD}  ENVIRONNEMENT INCOMPLET - corrigez les lignes ci-dessus,${NC}\n"
  printf "${RED}${BOLD}  puis relancez ce script.${NC}\n\n"
  exit 1
fi
