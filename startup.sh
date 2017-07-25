#!/bin/bash

set -e
initfile=$(echo $HOST_HOSTNAME)\.initialised
if [ -f /www/$(echo $initfile) ]; then
        echo 'initial configuration done.'
else    
        ### run once at container start IF no initialization file.
        ### if the .initialised file is removed, the container    
        ### will be reset to it's default state, unless the www
        ### folder is maintained.
        
        if [ ! -d /www ]; then
           mkdir -p /www
           echo "<? header('Location: /test.php'); ?>" > /www/index.php
           #cp /usr/share/javascript/jquery/jquery.min.js /synced/www/
           cp -TRv /tmp/www/ /www/
        fi
        echo -e "Do not remove this file.\nIf you do, container will be fully reset on next start." > /www/$(echo $initfile)
        date >> /www/$(echo $initfile)
fi