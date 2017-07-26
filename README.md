# docker-musicbrainz

docker create \
 -e PGDATABASE=musicbrainz \
 -e PGHOST=10.10.31.11 \
 -e PGPORT=5432 \
 -e PGUSER=musicbrainz \
 -e PGPASS=musicbrainz \
 -e PGID=1001 \
 -e PUID=1001 \
 -e TZ=Europe/Brussels \
 -e BRAINZCODE= \
 -p 5001:80 \
 -v /mnt/docker-dataset/musicbrainz/config:/config \
 -v /mnt/docker-dataset/musicbrainz/www:/www \
 --link musicbrainz-database:postgres \
 --name musicbrainz-web \
 --restart=always \
 trueosiris/docker-musicbrainz

Either set PGHOST & PGPORT or use --link to tag it to a databasecontainer (or even loadbalancer for a db). \
If PGHOST is set, --link will be ignored.
