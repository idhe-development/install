#!/bin/sh
VERT="\\033[1;32m"
NORMAL="\\033[0;39m"
ROUGE="\\033[1;31m"
ROSE="\\033[1;35m"
BLEU="\\033[1;34m"
BLANC="\\033[0;02m"
BLANCLAIR="\\033[1;08m"
JAUNE="\\033[1;33m"
CYAN="\\033[1;36m"

if [ $(id -u) != 0 ] ; then
  echo "Les droits de super-utilisateur (root) sont requis pour installer Kogimanager"
  echo "Veuillez lancer 'sudo $0' ou connectez-vous en tant que root, puis relancez $0"
  exit 1
fi

apt_install() {
  apt-get -y install "$@"
  if [ $? -ne 0 ]; then
    echo "${ROUGE}Ne peut installer $@ - Annulation${NORMAL}"
    exit 1
  fi
}

mysql_sql() {
  echo "$@" | mysql -uroot -p${MYSQL_ROOT_PASSWD}
  if [ $? -ne 0 ]; then
    echo "C${ROUGE}Ne peut exécuter $@ dans MySQL - Annulation${NORMAL}"
    exit 1
  fi
}

step_1_upgrade() {
  echo "---------------------------------------------------------------------"
  echo "${JAUNE}Commence l'étape 1 de la révision${NORMAL}"
  
  apt-get update
  apt-get -f install
  apt-get -y dist-upgrade
  echo "${VERT}étape 1 de la révision réussie${NORMAL}"
}

step_2_mainpackage() {
  echo "---------------------------------------------------------------------"
  echo "${JAUNE}Commence l'étape 2 paquet principal${NORMAL}"
  apt_install ntp ca-certificates unzip curl sudo cron
  apt-get -y install git
  apt -y remove node
  apt -y remove nodejs
  curl -sL https://deb.nodesource.com/setup_10.x|sudo -E bash -
  apt-get install -y nodejs
  apt-get -y install npm
  echo "${VERT}étape 2 paquet principal réussie${NORMAL}"
}

step_3_database() {
  echo "---------------------------------------------------------------------"
  echo "${JAUNE}Commence l'étape 3 base de données${NORMAL}"
  echo "mysql-server mysql-server/root_password password ${MYSQL_ROOT_PASSWD}" | debconf-set-selections
  echo "mysql-server mysql-server/root_password_again password ${MYSQL_ROOT_PASSWD}" | debconf-set-selections
  apt_install mariadb-client mariadb-common mariadb-server
  
  mysqladmin -u root password ${MYSQL_ROOT_PASSWD}
  
  systemctl status mysql > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    service mysql status
    if [ $? -ne 0 ]; then
      systemctl start mysql > /dev/null 2>&1
      if [ $? -ne 0 ]; then
        service mysql start > /dev/null 2>&1
      fi
    fi
  fi
  systemctl status mysql > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    service mysql status
    if [ $? -ne 0 ]; then
      echo "${ROUGE}Ne peut lancer mysql - Annulation${NORMAL}"
      exit 1
    fi
  fi
  echo "${VERT}étape 3 base de données réussie${NORMAL}"
}

step_4_kogimanager_download() {
  echo "---------------------------------------------------------------------"
  echo "${JAUNE}Commence l'étape 4 téléchargement de Kogimanager${NORMAL}"
  read -s -p "Entrer Token: " token

  dl_kogimanager() {
    echo "${JAUNE}Commence le téléchargement de Kogimanager${NORMAL}"
    git clone https://idhe-dev:$token@github.com/emahrv/Kogimanager.git
    if [ $? -ne 0 ]; then
      echo "${ROUGE}Ne peut télécharger Kogimanager depuis github${NORMAL}"
      read -p "Réessayer ? (Y/n)" 1 -r
      echo    # (optional) move to a new line
      if [[ ! $REPLY =~ ^[Yy]$ ]]
      then
        echo "${ROUGE}Annulation${NORMAL}"
        exit 1
      else
        dl_kogimanager
      fi
    else
      echo "${VERT}étape 4 téléchargement de Kogimanager réussie${NORMAL}"
      cd Kogimanager
    fi
  }
  dl_kogimanager
}

step_5_kogimanager_database_configuration() {
  echo "---------------------------------------------------------------------"
  echo "${JAUNE}commence l'étape 5 configuration de la base de donnée de Kogimanager${NORMAL}"
  echo "DROP USER 'admin'@'localhost';" | mysql -uroot -p${MYSQL_ROOT_PASSWD} > /dev/null 2>&1
  mysql_sql "CREATE USER 'admin'@'localhost' IDENTIFIED BY '${MYSQL_ADMIN_PASSWD}';"
  mysql_sql "GRANT ALL PRIVILEGES ON kogimanager.* TO 'admin'@'localhost';"
  mysql_sql "source /home/kogimanager/Kogimanager/kogimanager.sql"
  echo "${VERT}étape 5 configuration de la base de donnée de Kogimanager réussie${NORMAL}"
}

step_6_kogimanager_configuration() {
  echo "---------------------------------------------------------------------"
  echo "${JAUNE}commence l'étape 6 configuration de Kogimanager${NORMAL}"
  cat <<EOF >.env
  SESSION_SECRET= $SESSION_SECRET,
  MYSQL_ADMIN_PASSWD= $MYSQL_ADMIN_PASSWD
EOF

  echo "${VERT}étape 6 configuration de Kogimanager réussie${NORMAL}"
}

STEP=0
HTML_OUTPUT=0
MYSQL_ROOT_PASSWD=$(cat /dev/urandom | tr -cd 'a-f0-9' | head -c 20)
MYSQL_ADMIN_PASSWD=$(cat /dev/urandom | tr -cd 'a-f0-9' | head -c 20)
SESSION_SECRET=$(cat /dev/urandom | tr -cd 'a-f0-9' | head -c 64)

while getopts ":s:h:m:" opt; do
  case $opt in
    s) STEP="$OPTARG"
    ;;
    h) HTML_OUTPUT=1
    ;;
    m) MYSQL_ROOT_PASSWD="$OPTARG"
    ;;
    \?) echo "${ROUGE}Invalid option -$OPTARG${NORMAL}" >&2
    ;;
  esac
done

if [ ${HTML_OUTPUT} -eq 1 ]; then
  VERT="</pre><span style='color:green;font-weight: bold;'>"
  NORMAL="</span><pre>"
  ROUGE="<span style='color:red;font-weight: bold;'>"
  ROSE="<span style='color:pink;font-weight: bold;'>"
  BLEU="<span style='color:blue;font-weight: bold;'>"
  BLANC="<span style='color:white;font-weight: bold;'>"
  BLANCLAIR="<span style='color:blue;font-weight: bold;'>"
  JAUNE="<span style='color:#FFBF00;font-weight: bold;'>"
  CYAN="<span style='color:blue;font-weight: bold;'>"
  echo "<script>"
  echo "setTimeout(function(){ window.scrollTo(0,document.body.scrollHeight); }, 100);"
  echo "setTimeout(function(){ window.scrollTo(0,document.body.scrollHeight); }, 300);"
  echo "setTimeout(function(){ location.reload(); }, 1000);"
  echo "</script>"
  echo "<pre>"
fi

echo "${JAUNE}Bienvenue dans l'installateur de Kogimanager${NORMAL}"

case ${STEP} in
  0)
  echo "${JAUNE}Commence toutes les étapes de l'installation${NORMAL}"
  step_1_upgrade
  step_2_mainpackage
  step_3_database
  step_4_kogimanager_download
  step_5_kogimanager_database_configuration
  step_6_kogimanager_configuration
  echo "/!\ IMPORTANT /!\ Le mot de passe root MySQL est ${MYSQL_ROOT_PASSWD}"
  echo "Installation finie. Un redémarrage devrait être effectué"
  ;;
  1) step_1_upgrade
  ;;
  2) step_2_mainpackage
  ;;
  3) step_3_database
  ;;
  4) step_4_kogimanager_download
  ;;
  5) step_5_kogimanager_database_configuration
  ;;
  6) step_6_kogimanager_configuration
  ;;
  *) echo "${ROUGE}Désolé, Je ne peux sélectionner une ${STEP} étape pour vous !${NORMAL}"
  ;;
esac

exit 0