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
			[ $? -eq 0 ] && echo "User has been added to system!" || echo "Failed to add a user!"
		fi
		;;
	-h|--hostname)
		hostn=$(cat /etc/hostname)

		echo "Existing hostname is $hostn"

		echo "Enter new hostname: "
		read newhost

		sudo sed -i "s/$hostn/$newhost/g" /etc/hosts
		sudo sed -i "s/$hostn/$newhost/g" /etc/hostname

		declare -A HOST_KEYS
		HOST_KEYS=([DOMAIN]=$newhost)

		for key in "${!HOST_KEYS[@]}"; do
			vals="${HOST_KEYS[$key]}"
			sed -i "/^$key/ { s%=.*%="$vals"%; }" .env
		done

		sed -i "s/server_name.*/server_name $newhost/g" /etc/nginx/conf.d/default.conf
		sed -i "s/server_name.*/server_name $newhost/g" nginx/default.conf

		echo "Your new hostname is $newhost"

		#Press a key to reboot
		read -s -n 1 -p "Press any key to reboot"
		#sudo reboot
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
	*)
		echo "Select current action"
		echo "-h Change hostname"
		echo "-s Change S3FS credentials"
		echo "-u Add user"
		;;
esac