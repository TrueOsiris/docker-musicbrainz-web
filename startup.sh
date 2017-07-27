#!/bin/bash
set -e

### variables
initfile=musicbrainz.initialised
[[ -z "${PGPORT// }" ]] && port=5432 || port=$PGPORT
[[ -z "${PGHOST// }" ]] && dbhost="musicbrainz-database" || dbhost=$PGHOST

### functions
run_sql_file() {
   if [ ! -z "${PGHOST// }" ]; then
      echo "executing \"psql -h $dbhost -p $port -d musicbrainz -U $PGUSER -a -f $1\""
      PGOPTIONS='--client-min-messages=warning' psql -q -h $dbhost -p $port -d musicbrainz -U $PGUSER -a -f $1
   else
      echo "executing \"psql -d musicbrainz -U $PGUSER -a -f $1\""
      PGOPTIONS='--client-min-messages=warning' psql -q -d musicbrainz -U $PGUSER -a -f $1
   fi
}
export -f run_sql_file
run_sql_query() {
   if [ ! -z "${PGHOST// }" ]; then
      PGOPTIONS='--client-min-messages=warning' psql -q -h $dbhost -p $port -d musicbrainz -U $PGUSER -$1 -c "$2"
   else
      PGOPTIONS='--client-min-messages=warning' psql -q -d musicbrainz -U $PGUSER -$1 -c "$2"
   fi
}
export -f run_sql_query
sanitize_sql_file() {
   sed -i 's/CREATE TABLE IF NOT EXISTS/CREATE TABLE/g' $1
   sed -i 's/CREATE TABLE/CREATE TABLE IF NOT EXISTS/g' $1
   sed -i 's/\\set ON_ERROR_STOP 1/\\unset ON_ERROR_STOP/g' $1
   sed -i 's/\-\-.*$//g' $1
   sed -i ':a;N;$!ba;s/\n/ /g' $1
   sed -i 's/\t/ /g;s/ \+/ /g' $1 
   sed -i -r -e 's/(CREATE|ALTER)/\n\n&/g' $1
}
export -f sanitize_sql_file

### BEGIN
if [ ! -d /www ]; then
   mkdir -p /www
   echo "<? header('Location: /test.php'); ?>" > /www/index.php
   #cp /usr/share/javascript/jquery/jquery.min.js /synced/www/
   cp -TRv /tmp/www/ /www/
fi   
if [ ! -e ~/.pgpass ]; then
   echo creating ~/.pgpass
   echo "$dbhost:$port:musicbrainz:$PGUSER:$PGPASS"  > ~/.pgpass
   chmod 0600 ~/.pgpass
fi
if [ ! -d /www/sqls ]; then
   mkdir -p /www/sqls
fi
cd /www/sqls
if [ ! -e "/www/sqls/Extensions.sql" ]; then
   echo grabbing Extensions.sql
   wget --quiet https://raw.githubusercontent.com/metabrainz/musicbrainz-server/master/admin/sql/Extensions.sql
fi
if [ ! -e "/www/sqls/CreateTables.sql" ]; then 
   echo grabbing CreateTables.sql
   wget --quiet https://raw.githubusercontent.com/metabrainz/musicbrainz-server/master/admin/sql/CreateTables.sql
fi
if [ ! -e "/www/sqls/CreatePrimaryKeys.sql" ]; then 
   echo grabbing CreatePrimaryKeys.sql
   wget --quiet https://raw.githubusercontent.com/metabrainz/musicbrainz-server/master/admin/sql/CreatePrimaryKeys.sql
fi
if [ ! -e "/www/sqls/CreateIndexes.sql" ]; then
   echo grabbing CreateIndexes.sql
    wget --quiet https://raw.githubusercontent.com/metabrainz/musicbrainz-server/master/admin/sql/CreateIndexes.sql
fi
if [ ! -d /www/dump ]; then
    mkdir -p /www/dump
    echo "Downloading last Musicbrainz dump"
fi
cd /www/dump
if [ ! -e "/www/dump/LATEST" ]; then
    wget --quiet -nd -nH -P /www/dump http://ftp.musicbrainz.org/pub/musicbrainz/data/fullexport/LATEST
    echo "Latest version is $(cat /www/dump/LATEST)"
fi
LATEST="$(cat /www/dump/LATEST)"
if [ ! -e "/www/dump/mbdump-derived.tar.bz2" ]; then
   echo grabbing mbdump-derived.tar.bz2
   wget --quiet -nd -nH -P /www/dump http://ftp.musicbrainz.org/pub/musicbrainz/data/fullexport/$LATEST/mbdump-derived.tar.bz2
fi
if [ ! -e "/www/dump/mbdump.tar.bz2" ]; then
   echo grabbing mbdump.tar.bz2
   wget --quiet -nd -nH -P /www/dump http://ftp.musicbrainz.org/pub/musicbrainz/data/fullexport/$LATEST/mbdump.tar.bz2
fi
if [ ! -d /www/dump/extracted ]; then
   mkdir /www/dump/extracted
   echo "Uncompressing Musicbrainz mbdump-derived.tar.bz2"
   tar xjf /www/dump/mbdump-derived.tar.bz2 -C /www/dump/extracted
   echo "Uncompressing Musicbrainz mbdump.tar.bz2"
   tar xjf /www/dump/mbdump.tar.bz2 -C /www/dump/extracted
fi
if [ $(run_sql_query "t" "SELECT EXISTS(SELECT 1 FROM pg_namespace WHERE nspname = 'musicbrainz');") == "f" ]; then
   echo "creating database schema musicbrainz"
   run_sql_query "a" "CREATE SCHEMA musicbrainz"
else
   echo "database schema musicbrainz already exists"
fi
find /www/sqls/ -type f -exec bash -c 'sanitize_sql_file "{}"' \;
if [ ! -z "${PGHOST// }" ]; then
   echo "using environment variables PGHOST=$dbhost and PGPORT=$port to run sql initialization statements..."
else 
   echo "using --link as the target database to run sql initialization statements..."
fi 
run_sql_file /www/sqls/Extensions.sql
run_sql_file /www/sqls/CreateTables.sql
cd /www/dump/extracted
for f in /www/dump/extracted/mbdump/*
do
   tablename="${f:7}"
   echo "Importing $tablename table"
   echo "run_sql_query \"a\" \"COPY $tablename FROM '$f'\""
   chmod a+rX $f
   #psql -h postgresql -d musicbrainz -U $PGUSER -a -c "\COPY $tablename FROM '/www/dump/extracted/$f'"
done
cd ..

#echo "Creating Indexes and Primary Keys"
#psql -h postgresql -d musicbrainz -U $PGUSER -a -f CreatePrimaryKeys.sql
#psql -h postgresql -d musicbrainz -U $PGUSER -a -f CreateIndexes.sql
           
echo -e "Startup process completed.\nRun \"docker logs [containername]\" for details." > /www/$(echo $initfile)
date >> /www/$(echo $initfile)
echo $(cat /www/$initfile)
