# docker-musicbrainz

docker create \
 -e PGDATABASE=musicbrainz \
 -e PGHOST=postgres \
 -e PGPORT=5432 \
 -e PGUSER=musicbrainz \
 -e PGPASS=musicbrainz \
 -e PGID=1001 \
 -e PUID=1001 \
 -e TZ=Europe/Brussels \
 -e HOST_HOSTNAME=$(hostname) \
 -e HOST_IP=$(ip addr show enp0s3 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1) \
 -e BRAINZCODE= \
 -p 4567:80 \
 -v /mnt/docker-dataset/musicbrainz/www:/www \
 --name musicbrainz-web \
 --restart=always \
 trueosiris/docker-musicbrainz
