# docker build -t vixtract/nginx:1.0 .

FROM nginx:1.27.2-alpine

COPY ./html /var/www
COPY ./nginx.conf /etc/nginx/

VOLUME /etc/nginx
VOLUME /var/www

CMD ["nginx", "-g", "daemon off;"]