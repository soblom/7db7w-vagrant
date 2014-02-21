#!/usr/bin/env bash

#Database names
db_name_postgres="book"

#Save Postresql database state
echo Dumping Postgres database $db_name_postgres
pg_dump $db_name_postgres > /vagrant/01-postgresql/postgres_dump.sql

