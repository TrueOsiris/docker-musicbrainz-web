#!/bin/bash
set -e
if [ ! -d /www ]; then
   mkdir -p /www
   echo "<? header('Location: /test.php'); ?>" > /www/index.php
   #cp /usr/share/javascript/jquery/jquery.min.js /synced/www/
   cp -TRv /tmp/www/ /www/
fi   
echo "Creating Musicbrainz database structure"
echo "postgresql:5432:musicbrainz:$PGUSER:$PGPASS"  > ~/.pgpass
chmod 0600 ~/.pgpass
if [ ! -d /www/sqls ]; then
    mkdir -p /www/sqls
fi
cd /www/sqls
if [ ! -e "/www/sqls/Extensions.sql" ]; then
    wget --quiet https://raw.githubusercontent.com/metabrainz/musicbrainz-server/master/admin/sql/Extensions.sql
fi
if [ ! -e "/www/sqls/CreateTables.sql" ]; then 
    wget --quiet https://raw.githubusercontent.com/metabrainz/musicbrainz-server/master/admin/sql/CreateTables.sql
fi
if [ ! -e "/www/sqls/CreatePrimaryKeys.sql" ]; then 
    wget --quiet https://raw.githubusercontent.com/metabrainz/musicbrainz-server/master/admin/sql/CreatePrimaryKeys.sql
fi
if [ ! -e "/www/sqls/CreateIndexes.sql" ]; then
    wget --quiet https://raw.githubusercontent.com/metabrainz/musicbrainz-server/master/admin/sql/CreateIndexes.sql
fi
echo "Downloading last Musicbrainz dump"
if [ ! -d /www/dump ]; then
    mkdir -p /www/dump
fi
cd /www/dump
if [ ! -e "/www/dump/LATEST" ]; then
    wget --quiet -nd -nH -P /www/dump http://ftp.musicbrainz.org/pub/musicbrainz/data/fullexport/LATEST
fi
LATEST="$(cat /www/dump/LATEST)"
if [ ! -e "/www/dump/mbdump-derived.tar.bz2" ]; then
    wget --quiet -nd -nH -P /www/dump http://ftp.musicbrainz.org/pub/musicbrainz/data/fullexport/$LATEST/mbdump-derived.tar.bz2
fi
if [ ! -e "/www/dump/mbdump.tar.bz2" ]; then
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
psql -h $PGHOST -p $PGPORT -d musicbrainz -U $PGUSER -a -c "CREATE SCHEMA musicbrainz"
   #psql -h postgresql -d musicbrainz -U $PGUSER -a -f Extensions.sql
   #psql -h postgresql -d musicbrainz -U $PGUSER -a -f CreateTables.sql

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
           
echo -e "Do not remove this file.\nIf you do, container will be fully reset on next start." > /www/$(echo $initfile)
date >> /www/$(echo $initfile)
