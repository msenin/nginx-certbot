# Steps to build base nginx image:
# docker build -t <your_registry>/nginx-certbot:1.16-alpine .
# docker push <your_registry>/nginx-certbot:1.16-alpine

# For instance:
# docker build -t docker-registry.labs.intellij.net/jetbrains/nginx-certbot:1.16-alpine .
# docker push docker-registry.labs.intellij.net/jetbrains/nginx-certbot:1.16-alpine

FROM nginx:1.16-alpine

COPY entrypoint.sh /
COPY periodic-certbot /etc/periodic/daily/

RUN apk add --update \
        ca-certificates \
        openssl \
        binutils \
        bash \
        acl \
        certbot \
    && mkdir -p /etc/nginx/conf.ssl.d/ /etc/nginx/certs/ /usr/share/nginx/certbot/ \
    && chmod +x /entrypoint.sh /etc/periodic/daily/periodic-certbot

COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/nginx.certbot.conf /etc/nginx/conf.d/nginx.certbot.conf
COPY conf/ssl.conf /etc/nginx/ssl.conf

WORKDIR /

EXPOSE 80 443

VOLUME [ "/etc/letsencrypt", "/var/lib/letsencrypt", "/etc/nginx/ssl" ]

ENTRYPOINT ["/entrypoint.sh"]
