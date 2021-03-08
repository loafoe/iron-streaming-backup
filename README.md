# iron-streaming-backup

A Docker image that you can schedule on HSDP IronIO to perform PostgreSQL backups to an S3 bucket

# Features
- Streaming backups so not dependent on runner disk storage
- Compresses and encrypts backups

# Usage

## Prerequisites
- IronIO CLI
- Siderite CLI
- Provisioned: one or more PostgreSQL RDS instances you want to backup
- Provisioned: HSDP Iron instance
- Provisioned: HSDP S3 bucket for storing backups

## Preparing payload.json
As the image uses [siderite](https://github.com/philips-labs/siderite) for runtime orchestration all the required credentials will be passed through a `payload.json` file which will be stored encrypted in the IronIO scheduled task definition.

The payload should have the following `cmd` and `env`-ironment variables

```json
{
  "version": "1",
  "cmd": ["/app/backup.sh"],
  "env": {
	"PGPASS_FILE_BASE64": "cG9zdGdyZXMtZGIuZGVmc2ZzYS51cy1lYXN0LTEucmRzLmFtYXpvbmF3cy5jb206NTQzMjpoc2RwX3BnOnh4VXNlckF4eDp5eVBhc3N3ZEF5eTpkYjEKcG9zdGdyZXMtZGIuZGVmc2ZzYi51cy1lYXN0LTEucmRzLmFtYXpvbmF3cy5jb206NTQzMjpoc2RwX3BnOnh4VXNlckJ4eDp5eVBhc3N3ZEJ5eTpkYjIK",
	"PASS_FILE_BASE64": "TXlTZWNyZXRQYXNzd29yZAo=",
	"AWS_ACCESS_KEY_ID": "APIKeyHere",
	"AWS_SECRET_ACCESS_KEY": "SecretKeyHere",
	"S3_BUCKET": "cf-s3-some-random-uuid-here"
  }
}
```

### PGPASS_FILE_BASE64
The pgpass file contains the credentials for each PostgreSQL database you want to back up. The format is one database per line:

```
hostname:port:database:username:password:someprefix
```

Example:

```
postgres-db.defsfsa.us-east-1.rds.amazonaws.com:5432:hsdp_pg:xxUserAxx:yyPasswdAyy:db1
postgres-db.defsfsb.us-east-1.rds.amazonaws.com:5432:hsdp_pg:xxUserBxx:yyPasswdByy:db2
```

Once you've prepared the file encode it using base64 to get the value to use:

```shell
cat pgpass|base64
cG9zdGdyZXMtZGIuZGVmc2ZzYS51cy1lYXN0LTEucmRzLmFtYXpvbmF3cy5jb206NTQzMjpoc2RwX3BnOnh4VXNlckF4eDp5eVBhc3N3ZEF5eTpkYjEKcG9zdGdyZXMtZGIuZGVmc2ZzYi51cy1lYXN0LTEucmRzLmFtYXpvbmF3cy5jb206NTQzMjpoc2RwX3BnOnh4VXNlckJ4eDp5eVBhc3N3ZEJ5eTpkYjIK
```

### PASS_FILE_BASE64
The pass file contains the key (password) that will be used to encrypt the database backups using AES-256

```shell
echo -n 'MySecretPassword'|base64
TXlTZWNyZXRQYXNzd29yZA==
```

### AWS_ACCESS_KEY_ID
This should be the `api_key` of the HSDP S3 Bucket you provisioned

### AWS_SECRET_ACCESS_KEY
This should be the `secret_key` of the HSDP S3 Bucket you provisioned

### S3_BUCKET
This should be the `bucket` of the HSDP S3 Bucket you provisioned

# Scheduling the task
Once you've prepared the `payload.json` file can you encrypt it using `siderite`

```shell
cat payload.json|siderite encrypt > payload.enc
```

Now you need the IronIO cluster ID

```shell
cat ~/.iron.json |jq -r .cluster_info[0].cluster_id
56someclusteridhere34554
````

Register the `iron-streaming-backup` Docker image in IronIO. You only need to do this once or after updating or publishing the Docker image in this repository

```shell
iron register philipslabs/iron-streaming-backup:latest
```

Finally, you can schedule the task. In the below example the backup task will run once every day

```shell
iron worker schedule \
	-cluster 56someclusteridhere34554 \
	-run-every 86400 \
	-payload-file payload.enc philipslabs/iron-streaming-backup
```

# Bucket lifecycle policy
It is advised to set a S3 Bucket lifecycle policy. A good practice is to move your database backups to the `GLACIER` storage class after a couple of days and to set a expiration date to automatically delete older backups. The below policy moves dumps to `CLACIER` after 7 days and deletes them after 6 months (180 days)

```json
[
  {
    "Expiration": {
      "Days": 180
    },
    "ID": "Move to Glacier and expire after 6 months",
    "Prefix": "",
    "Status": "Enabled",
    "Transitions": [
      {
        "Days": 7,
        "StorageClass": "GLACIER"
      }
    ]
  }
]
```

# Retrieving and decrypting a backup
- Copy the `.gz.aes` file from the bucket back to your restore system
- Decrypting the file, assuming your password is stored in the file `${password_file}`:
```shell
openssl enc -in backup_file.gz.aes -aes-256-cbc -d -pass file:${password_file} |gzip -d > pg_dump_file.sql
```

# License

License is MIT
