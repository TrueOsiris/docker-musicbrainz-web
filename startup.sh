#!/bin/bash
set -e
initfile=musicbrainz.initialised
if [ ! -d /www ]; then
   mkdir -p /www
   echo "<? header('Location: /test.php'); ?>" > /www/index.php
   #cp /usr/share/javascript/jquery/jquery.min.js /synced/www/
   cp -TRv /tmp/www/ /www/
fi   
if [ ! -e ~/.pgpass ]; then
   echo creating ~/.pgpass
   echo "$PGHOST:$PGPORT:musicbrainz:$PGUSER:$PGPASS"  > ~/.pgpass
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
#psql -h $PGHOST -p $PGPORT -d musicbrainz -U $PGUSER -l
if [ $(psql -h $PGHOST -p $PGPORT -d musicbrainz -U $PGUSER -t -c "SELECT EXISTS(SELECT 1 FROM pg_namespace WHERE nspname = 'musicbrainz');") == "f" ]; then
   echo "creating database schema musicbrainz"
   psql -h $PGHOST -p $PGPORT -d musicbrainz -U $PGUSER -a -c "CREATE SCHEMA musicbrainz"
else
   echo "database schema musicbrainz already exists"
fi
#sanitize sql files
find /www/sqls/ -type f | xargs sed -i 's/CREATE TABLE IF NOT EXISTS/CREATE TABLE/g'
find /www/sqls/ -type f | xargs sed -i 's/CREATE TABLE/CREATE TABLE IF NOT EXISTS/g'
find /www/sqls/ -type f | xargs sed -i 's/\\set ON_ERROR_STOP 1/\\unset ON_ERROR_STOP 0/g'
echo "executing \"psql -h $PGHOST -p $PGPORT -d musicbrainz -U $PGUSER -a -f /www/sqls/Extensions.sql\""
psql -h $PGHOST -p $PGPORT -d musicbrainz -U $PGUSER -a -f /www/sqls/Extensions.sql
echo "executing \"psql -h $PGHOST -p $PGPORT -d musicbrainz -U $PGUSER -a -f /www/sqls/CreateTables.sql\""
psql -h $PGHOST -p $PGPORT -d musicbrainz -U $PGUSER -a -f /www/sqls/CreateTables.sql
 

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
           
echo -e "Startup process completed.\nRun \"docker logs \[containername\]\" for details." > /www/$(echo $initfile)
date >> /www/$(echo $initfile)
echo $(cat $initfile)
