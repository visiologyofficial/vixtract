FROM nginx:1.21.6

COPY ./html /var/www
COPY ./nginx.conf /etc/nginx/

VOLUME /etc/nginx
VOLUME /var/www

CMD ["nginx", "-g", "daemon off;"]