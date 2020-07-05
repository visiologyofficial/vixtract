#!/usr/bin/env bash

source .env

BUCKET=${BUCKET}
DESTINATION=${DESTINATION}
BACKUP=${BACKUP}

# mounting S3 BUCKET for BACKUP as a local drive
s3fs $BUCKET $DESTINATION -o url=http://storage.yandexcloud.net -o passwd_file=/etc/passwd-s3fs -o use_path_request_style -o nonempty

# rsync local files to S3 BUCKET
rsync -avz --inplace --size-only $BACKUP $DESTINATION
