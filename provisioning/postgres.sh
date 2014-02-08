#Data base user and password for postgres
db_user="vagrant"
db_password="Ib-Bit=Cy-wry>shtA7t-Vo-freb"


###
# POSTGRES
###
echo "Postgres soll installiert sein"
sudo apt-get -y install postgresql postgresql-contrib

echo "Postgres soll konfiguriert sein"
sudo -u postgres psql -c "create user \"$db_user\" with password '$db_password'"
sudo -u postgres psql -c "alter user \"$db_user\" createdb"

echo "Konfiguriere Datenbank 'book'"
sudo -u vagrant createdb book
for extension in tablefunc dict_xsyn fuzzystrmatch pg_trgm cube
do
	echo Install Postgres Extension $extension für db:book
	sudo -u postgres psql book -c "CREATE EXTENSION $extension"
done
