FROM nginx:latest

RUN groupadd -g 1000 nginxx
RUN useradd -d /opt -s /bin/bash -u 1000 -g 1000 nginxx
# User and group own home directory
RUN chown -R nginxx:nginxx /opt
 
# Necessary steps to avoid permission errors
RUN touch /var/run/nginx.pid \
 && chown -R nginxx:nginxx /var/run/nginx.pid /var/cache/nginx /var/log/nginx

EXPOSE 80 443

