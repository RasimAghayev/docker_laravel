FROM nginx:stable-alpine

ADD ./nginx/default.conf /etc/nginx/conf.d/default.conf

RUN mkdir -p /var/www/html
# WORKDIR /var/www/html
# ADD ./src /var/www/html
# ADD ./src/ /var/www/html

# RUN chmod o+w /var/www/html/storage/ -R