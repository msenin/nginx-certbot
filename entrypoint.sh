#!/bin/bash

if [[ -z "${DEFAULT_DOMAIN}" ]] ; then
  echo "DEFAULT_DOMAIN not defined!"
  exit 1
fi

sed -i 's/server_name _default_server_name_;/server_name '${DEFAULT_DOMAIN}';/' /etc/nginx/conf.d/nginx.certbot.conf

if [[ -z "${CERTBOT_ACCOUNT_EMAIL}" ]] ; then
  echo "CERTBOT_ACCOUNT_EMAIL not defined!"
  exit 1
fi

if [[ -z "${CERTBOT_DOMAINS}" ]] ; then
  echo "CERTBOT_DOMAINS not defined!"
  exit 1
fi

echo "export CERTBOT_FLAGS=${CERTBOT_FLAGS}" > /etc/default/cron
echo "export CERTBOT_RENEW_FLAGS=${CERTBOT_RENEW_FLAGS}" >> /etc/default/cron

if [[ ! -f /etc/nginx/certs/dhparams.pem ]]
then
  echo -n "Generating /etc/nginx/certs/dhparams.pem... "
  openssl dhparam -out /etc/nginx/certs/dhparams.pem 2048
  chmod 400 /etc/nginx/certs/dhparams.pem
  echo "Done."
fi

################################################################
# Certificates from Let's Encrypt
################################################################

DOMAINS_WITHOUT_CERTIFICATES=""
for DOMAIN in ${CERTBOT_DOMAINS}
do
  # check config exists
  if [[ ! -f /etc/nginx/conf.ssl.d/${DOMAIN}.conf ]]
  then
    echo "Configuration file /etc/nginx/conf.ssl.d/${DOMAIN}.conf for ${DOMAIN} not found!"
    exit 1
  fi
  # run only if there is no certificate for ${DOMAIN}
  if [[ -f /etc/letsencrypt/live/${DOMAIN}/fullchain.pem && -f /etc/letsencrypt/live/${DOMAIN}/privkey.pem && -f /etc/letsencrypt/live/${DOMAIN}/chain.pem ]]
  then
    echo "Certificate for ${DOMAIN} already exists."
    if [[ ! -f /etc/nginx/conf.d/${DOMAIN}.conf ]]
    then
      ln -s /etc/nginx/conf.ssl.d/${DOMAIN}.conf /etc/nginx/conf.d/${DOMAIN}.conf
    fi
  else
    DOMAINS_WITHOUT_CERTIFICATES="${DOMAINS_WITHOUT_CERTIFICATES} ${DOMAIN}"
    # remove symlink if it exists
    if [[ -f /etc/nginx/conf.d/${DOMAIN}.conf ]]
    then
      rm /etc/nginx/conf.d/${DOMAIN}.conf
    fi
    # create folder for verification
    mkdir -p /usr/share/nginx/certbot/${DOMAIN}/
  fi
done

echo "Domains without certificates: [ ${DOMAINS_WITHOUT_CERTIFICATES} ]"
for DOMAIN in ${DOMAINS_WITHOUT_CERTIFICATES}
do
  # Run only if there is no certificate for ${DOMAIN}
  echo "Run certbot to get certificate for ${DOMAIN}"
  /usr/bin/certbot certonly ${CERTBOT_FLAGS} --standalone --preferred-challenges http-01 --email ${CERTBOT_ACCOUNT_EMAIL} --agree-tos --non-interactive --domains ${DOMAIN}
  ret_code=$?
  if [[ ${ret_code} != 0 ]]; then
    printf "Error: %d code when executing certbot command" ${ret_code}
  else
    # add symlink to domain's config
    if [[ -f /etc/nginx/conf.ssl.d/${DOMAIN}.conf ]]
    then
      ln -s /etc/nginx/conf.ssl.d/${DOMAIN}.conf /etc/nginx/conf.d/${DOMAIN}.conf
    fi
  fi
done

# Start cron in order to update certificates from Let's Encrypt
/usr/sbin/crond -b -l 8

# Start nginx in foreground mode
echo "Starting nginx as main container process..."
exec nginx -g "daemon off;"