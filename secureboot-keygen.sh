[ -n "${DEBUG}" ] && set -x
set -e

generate_keys() {
    local NAME=$(hostname)
    local key_root="/etc/secureboot"
    local key_paths=($key_root/keys/{db,dbx,KEK,PK})

    for path in "${key_paths[@]}"; do
        mkdir -p $path
    done

    local db_dir=${key_paths[0]}
    local kek_dir=${key_paths[2]}
    local pk_dir=${key_paths[3]}

    GUID="$(uuidgen -r)"
    echo ${GUID} > $key_root/UUID.txt

    # generate platform key
    openssl req -new -x509 \
      -subj "/CN=${NAME} PK/" -days 3650 -nodes \
      -newkey rsa:4096 -sha256 \
      -keyout $pk_dir/PK.key -out $pk_dir/PK.crt

    openssl x509 -in $pk_dir/PK.crt -out $pk_dir/PK.cer -outform DER

    # generate key exchange key
    openssl req -new -x509 \
        -subj "/CN=${NAME} KEK/" -days 3650 -nodes \
        -newkey rsa:4096 -sha256 \
        -keyout $kek_dir/KEK.key -out $kek_dir/KEK.crt

    openssl x509 -in $kek_dir/KEK.crt -out $kek_dir/KEK.cer -outform DER

    # generate signature database key
    openssl req -new -x509 \
        -subj "/CN=${NAME} DB/" -days 3650 -nodes \
        -newkey rsa:4096 -sha256 \
        -keyout $db_dir/db.key -out $db_dir/db.crt

    openssl x509 -in $db_dir/db.crt -out $db_dir/db.cer -outform DER

    cert-to-efi-sig-list -g ${GUID} $pk_dir/PK.crt $pk_dir/PK.esl
    cert-to-efi-sig-list -g ${GUID} $kek_dir/KEK.crt $kek_dir/KEK.esl
    cert-to-efi-sig-list -g ${GUID} $db_dir/db.crt $db_dir/db.esl

    sign-efi-sig-list \
        -t "$(date --date='1 second' +'%Y-%m-%d %H:%M:%S')" \
        -k $pk_dir/PK.key -c $pk_dir/PK.crt \
        PK $pk_dir/PK.esl $pk_dir/PK.auth
    sign-efi-sig-list \
        -t "$(date --date='1 second' +'%Y-%m-%d %H:%M:%S')" \
        -k $pk_dir/PK.key -c $pk_dir/PK.crt \
        PK /dev/null $pk_dir/nukePK.auth
    sign-efi-sig-list \
        -t "$(date --date='1 second' +'%Y-%m-%d %H:%M:%S')" \
        -k $pk_dir/PK.key -c $pk_dir/PK.crt \
        KEK $kek_dir/KEK.esl $kek_dir/KEK.auth
    sign-efi-sig-list \
        -t "$(date --date='1 second' +'%Y-%m-%d %H:%M:%S')" \
        -k $kek_dir/KEK.key -c $kek_dir/KEK.crt \
        DB $db_dir/db.esl $db_dir/db.auth

    for path in "${key_paths[@]}"; do
        chmod -f 0600 $path/*.key || true
    done
}

generate_keys