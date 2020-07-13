#!/usr/bin/env bash

if [ "$EUID" -ne 0 ]
  then echo "Please run with sudo"
  exit
fi

### Source file
source .env

ACTION_NAME=$1

case "$ACTION_NAME" in
	-u|--user)
		read -p "Enter username : " username
		read -s -p "Enter password : " password
		egrep "^$username" /etc/passwd >/dev/null
		if [ $? -eq 0 ]; then
			echo "$username exists!"
			exit 1
		else
			pass=$(perl -e 'print crypt($ARGV[0], "password")' $password)
			useradd -m -p "$pass" "$username"
			usermod -aG etl "$username"
			cp -r tutorials "/home/$username"
			service cronicle stop
			node /opt/cronicle/bin/cronicle_useradd.js $username $password
			service cronicle start
			[ $? -eq 0 ] && echo "User has been added to system!" || echo "Failed to add a user!"
		fi
		;;
	-a|--admin)
		read -s -p "Enter Cronicle admin password : " password
		service cronicle stop
		node /opt/cronicle/bin/storage-cli.js admin admin "$password"
		service cronicle start
		;;
	-h|--hostname)
		hostn=$(cat /etc/hostname)

		echo "Existing hostname is $hostn"
		read -p "Enter new hostname: " newhost

    if [ -z "$newhost" ]
    then
      service cronicle stop

      sed -i "s/\"server_comm_use_hostnames\".*/\"server_comm_use_hostnames\": false,/g" /opt/cronicle/conf/config.json
      sed -i "s/\"web_socket_use_hostnames\".*/\"web_socket_use_hostnames\": false,/g" /opt/cronicle/conf/config.json

  		service cronicle start
    else
      sed -i "s/$hostn/$newhost/g" /etc/hosts
  		sed -i "s/$hostn/$newhost/g" /etc/hostname

  		declare -A HOST_KEYS
  		HOST_KEYS=([DOMAIN]=$newhost)

  		for key in "${!HOST_KEYS[@]}"; do
  			vals="${HOST_KEYS[$key]}"
  			sed -i "/^$key/ { s%=.*%="$vals"%; }" .env
  		done

  		sed -i "s/server_name.*/server_name $newhost/g" /etc/nginx/conf.d/default.conf
  		sed -i "s/server_name.*/server_name $newhost/g" nginx/default.conf

  		### Nginx
  		service nginx restart

  		echo "Your new hostname is $newhost"

  		### Cronicle
  		service cronicle stop

      /opt/cronicle/bin/storage-cli.js get global/servers/0 > SERVERS.JSON
  		sed -i "s/hostname.*/hostname\": \"${newhost}\",/g" SERVERS.JSON
  		cat SERVERS.JSON | /opt/cronicle/bin/storage-cli.js put global/servers/0

      /opt/cronicle/bin/storage-cli.js get global/server_groups/0 > SERVERGROUPS.JSON
      sed -i "s/\"regexp\": \"\^.*/\"regexp\": \"^(${newhost})\$\",/g" SERVERGROUPS.JSON
  		cat SERVERGROUPS.JSON | /opt/cronicle/bin/storage-cli.js put global/server_groups/0

      sed -i "s/\"server_comm_use_hostnames\".*/\"server_comm_use_hostnames\": true,/g" /opt/cronicle/conf/config.json
      sed -i "s/\"web_socket_use_hostnames\".*/\"web_socket_use_hostnames\": true,/g" /opt/cronicle/conf/config.json

  		service cronicle start
  		rm SERVERS.JSON
      rm SERVERGROUPS.JSON

  		#Press a key to reboot
  		echo "WARNING: You need to reboot for changes to take effect"
  		#reboot
    fi
		;;
	-s|--s3fs)
		read -p "Enter ACCESS_KEY_ID : " ACCESS_KEY_ID
		read -p "Enter BUCKET : " BUCKET
		read -s -p "Enter SECRET_ACCESS_KEY : " SECRET_ACCESS_KEY

		### S3FS array
		declare -A S3_KEYS
		S3_KEYS=([ACCESS_KEY_ID]=$ACCESS_KEY_ID [SECRET_ACCESS_KEY]=$SECRET_ACCESS_KEY [BUCKET]=$BUCKET)

		for key in "${!S3_KEYS[@]}"; do
			vals="${S3_KEYS[$key]}"
			sed -i "/^$key/ { s%=.*%="$vals"%; }" .env
		done
		;;
	-ssl|--cert)
		read -p "Enable SSL ? Type [Y/n]" -n 1 -r SSL_REPLY
		if [[ $SSL_REPLY =~ ^[Yy]$ ]]
		then
		    SSL_EN=1
		else
			SSL_EN=0
		fi
		echo
		### SSL array
		declare -A SSL_KEYS
		SSL_KEYS=([SSL]=$SSL_EN)

		for key in "${!SSL_KEYS[@]}"; do
			vals="${SSL_KEYS[$key]}"
			sed -i "/^$key/ { s%=.*%="$vals"%; }" .env
		done

		### HTTPS DISABLE
		if [ ${SSL_EN} != "1" ];
		then
			cp nginx/default.conf /etc/nginx/conf.d/default.conf
			service nginx restart
			sed -i "s/\"https\": true,/\"https\": false,/g" /opt/cronicle/conf/config.json
			service cronicle restart
		fi

	    ### HTTPS ENABLE
	    if [ ${SSL_EN} != "0" ];
	    then
	    	certbot --nginx -w /var/www/html \
	    		--no-eff-email \
	    		--redirect \
	    		--email ${EMAIL} \
	    		-d ${DOMAIN} \
	    		--agree-tos \
	    		--force-renewal

	    	sed -i "s/https_cert_file.*/https_cert_file\": \"\/etc\/letsencrypt\/live\/${DOMAIN}\/fullchain.pem\",/g" /opt/cronicle/conf/config.json
			sed -i "s/https_key_file.*/https_key_file\": \"\/etc\/letsencrypt\/live\/${DOMAIN}\/privkey.pem\",/g" /opt/cronicle/conf/config.json
			sed -i "s/\"https\": false,/\"https\": true,/g" /opt/cronicle/conf/config.json
			service cronicle restart
	    fi

		;;
	-p|--psql)
		read -s -p "Enter password for default PostgreSQL user ('etl'): " PSQL_PASSWORD

		### SSL array
		declare -A PSQL_KEYS
		PSQL_KEYS=([PSQL_PASS]=$PSQL_PASSWORD)

		for key in "${!PSQL_KEYS[@]}"; do
			vals="${PSQL_KEYS[$key]}"
			sed -i "/^$key/ { s%=.*%="$vals"%; }" .env
		done

		### Update postgres user and password
		sudo -u postgres bash -c "psql -c \"CREATE USER ${PSQL_USER} WITH PASSWORD '${PSQL_PASS}';\""
		sudo -u postgres bash -c "psql -c \"CREATE DATABASE ${PSQL_DB};\""
		sudo -u postgres bash -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE ${PSQL_DB} TO ${PSQL_USER};\""
		sudo -u postgres bash -c "psql -c \"ALTER USER ${PSQL_USER} WITH PASSWORD '${PSQL_PASS}';\""

		;;
	*)
		echo "Select current action"
		echo "-h Configure hostname/domain"
		echo "-s Configure S3FS credentials (S3 bucket mount)"
		echo "-u Add user account"
		echo "-a Configure Cronicle admin password"
		echo "-p Configure PostgreSQL password for default user ('etl')"
		echo "-ssl Enable or disable HTTPS"
		;;
esac
