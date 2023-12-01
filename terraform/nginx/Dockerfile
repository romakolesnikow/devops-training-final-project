FROM nginx:latest

WORKDIR /etc/nginx

COPY nginx.conf /etc/nginx/nginx.conf

#RUN chown -R www-data:www-data /var/www/html

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]