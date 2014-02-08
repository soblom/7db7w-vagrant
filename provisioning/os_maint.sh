#updating all security relevant packages automatically
echo "Pakete werden aktualisiert\n"
sudo apt-get -y update 
sudo apt-get -y upgrade
sudo apt-get -y autoremove
sudo apt-get -y autoclean  

