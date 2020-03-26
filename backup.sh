#!/usr/bin/env bash
#
# ----- Config start -----
timestamp=`date +%Y%m%d%H%M%S`
s3_bucket=${S3_BUCKET}
password_file=${PASSWORD_FILE:-~/.pass}
pgpass_file=${PGPASS_FILE:-~/.pgpass}

if [ -z "$PGPASS_FILE_BASE64" ]; then
    echo "Specify pgpass content in base64 encoded PGPASS_FILE_BASE64 variable..."
    exit 1
fi

if [ -z "$PASS_FILE_BASE64" ]; then
    echo "Specify password file content in base64 encoded PASS_FILE_BASE64 variable..."
    exit 1
fi

umask 077
echo $PGPASS_FILE_BASE64|base64 -d > $pgpass_file
echo $PASS_FILE_BASE64|base64 -d > $password_file

if [ -z "$s3_bucket" ]; then
    echo "Specify S3 destination bucket in S3_BUCKET variable..."
    exit 1
fi

if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    echo "Specify AWS_ACCESS_KEY_ID variable..."
    exit 1
fi

if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "Specify AWS_SECRET_ACCESS_KEY variable..."
    exit 1
fi

if [ ! -f "${password_file}" ]; then
    echo "Password file ${password_file} does not exist..."
    exit 1
fi

if [ ! -f "${pgpass_file}" ]; then
    echo "PGPass file ${pgpass_file} does not exist..."
    exit 1
fi

echo Using configuration
echo -------------------
echo     S3 Bucket: ${s3_bucket}
echo Password file: ${password_file}
echo   PGPass file: ${pgpass_file}
echo       OpenSSL: `openssl version`
# ----- Config end -----

echo Processing...
for i in `cat ${pgpass_file}`;do
	OFS=$IFS
	IFS=:
	read -ra FIELDS <<< "$i"
	db_host=${FIELDS[0]}
	db_port=${FIELDS[1]}
	db_name=${FIELDS[2]}
	db_user=${FIELDS[3]}
	db_password=${FIELDS[4]}
	db_service=${FIELDS[5]}
        ignore=${FIELDS[6]}
	if [ -n "$1" ]; then
		if [ "$1" != "${db_service}" ]; then
			echo "Skipping ${db_service}"
			continue
		fi
		if [ "ignore" == "${ignore}" ]; then
                        echo "Ignoring ${db_service}"
			continue
		fi
	fi

	outfile=${db_service}-${timestamp}.gz.aes
	echo Backing up stream to s3://${s3_bucket}/${outfile} ...
	pg_dump -h ${db_host} -p ${db_port} -U ${db_user} ${db_name} | gzip | openssl enc -aes-256-cbc -e -pass file:${password_file} | /app/gof3r put -b ${s3_bucket} -k ${outfile} --no-md5
	IFS=$OFS
done
