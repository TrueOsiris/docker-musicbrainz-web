#!/bin/bash
set -e

### variables
initfile=musicbrainz.initialised
[[ -z "${PGPORT// }" ]] && port=5432 || port=$PGPORT
[[ -z "${PGHOST// }" ]] && dbhost="musicbrainz-database" || dbhost=$PGHOST

### functions
run_sql_file() {
   if [ ! -z "{$PGHOST// }" ]; then
      echo "executing \"psql -h $dbhost -p $port -d musicbrainz -U $PGUSER -a -f $1\""
      psql -q -h $dbhost -p $port -d musicbrainz -U $PGUSER -a -f $1
   else
      echo "executing \"psql -d musicbrainz -U $PGUSER -a -f $1\""
      psql -q -d musicbrainz -U $PGUSER -a -f $1
   fi
}
run_sql_query() {
   if [ ! -z "{$PGHOST// }" ]; then
      psql -q -h $dbhost -p $port -d musicbrainz -U $PGUSER -$1 -c "$2"
   else
      psql -q -d musicbrainz -U $PGUSER -$1 -c "$2"
   fi
}
sanitize_sql_file() {
   sed -i 's/CREATE TABLE IF NOT EXISTS/CREATE TABLE/g' $1
   sed -i 's/CREATE TABLE/CREATE TABLE IF NOT EXISTS/g' $1
   sed -i 's/\\set ON_ERROR_STOP 1/\\unset ON_ERROR_STOP/g' $1
   sed -i 's/\-\-.*$//g' $1
   #sed -i -r -e 's/\n/ /g' $1
   sed -i ':a;N;$!ba;s/\n/ /g' $1
   sed -i 's/\t/ /g;s/ \+/ /g' $1 
   sed -i -r -e 's/(CREATE|ALTER)/\n\n&/g' $1
}



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
if [ ! -d /www/dump/mbdump-derived ]; then
   mkdir /www/dump/mbdump-derived
   echo "Uncompressing Musicbrainz mbdump-derived.tar.bz2"
   tar xjf /www/dump/mbdump-derived.tar.bz2 -C /www/dump/mbdump-derived
fi
if [ ! -d /www/dump/mbdump ]; then
   mkdir /www/dump/mbdump
   echo "Uncompressing Musicbrainz mbdump.tar.bz2"
   tar xjf /www/dump/mbdump.tar.bz2 -C /www/dump/mbdump
fi
#if [ $(psql -h $PGHOST -p $PGPORT -d musicbrainz -U $PGUSER -t -c "SELECT EXISTS(SELECT 1 FROM pg_namespace WHERE nspname = 'musicbrainz');") == "f" ]; then
if [ $(run_sql_query "t" "SELECT EXISTS(SELECT 1 FROM pg_namespace WHERE nspname = 'musicbrainz');") == "f" ]; then
   echo "creating database schema musicbrainz"
   run_sql_query "a" "CREATE SCHEMA musicbrainz"
   #psql -h $PGHOST -p $PGPORT -d musicbrainz -U $PGUSER -a -c "CREATE SCHEMA musicbrainz"
else
   echo "database schema musicbrainz already exists"
fi
#sanitize sql files
#find /www/sqls/ -type f | xargs sed -i 's/CREATE TABLE IF NOT EXISTS/CREATE TABLE/g'
#find /www/sqls/ -type f | xargs sed -i 's/CREATE TABLE/CREATE TABLE IF NOT EXISTS/g'
#find /www/sqls/ -type f | xargs sed -i 's/\\set ON_ERROR_STOP 1/\\unset ON_ERROR_STOP/g'
find /www/sqls/ -type f -exec sanitize_sql_file "{}" \;
if [ ! -z "{$PGHOST// }" ]; then
   echo "using environment variables PGHOST=$PGHOST and PGPORT=$PGPORT to run sql initialization statements..."
else 
   echo "using --link as the target database to run sql initialization statements..."
fi 
run_sql_file /www/sqls/Extensions.sql
run_sql_file /www/sqls/CreateTables.sql
   
#for f in mbdump/*
#do
#   tablename="${f:7}"
#   echo "Importing $tablename table"
#   echo "psql -h postgresql -d musicbrainz -U $PGUSER -a -c COPY $tablename FROM '/tmp/$f'"
#   chmod a+rX /tmp/$f
#   psql -h postgresql -d musicbrainz -U $PGUSER -a -c "\COPY $tablename FROM '/tmp/$f'"
#done

#echo "Creating Indexes and Primary Keys"
#psql -h postgresql -d musicbrainz -U $PGUSER -a -f CreatePrimaryKeys.sql
#psql -h postgresql -d musicbrainz -U $PGUSER -a -f CreateIndexes.sql
           
echo -e "Startup process completed.\nRun \"docker logs [containername]\" for details." > /www/$(echo $initfile)
date >> /www/$(echo $initfile)
echo $(cat /www/$initfile)
