FROM openresty/openresty:1.21.4.2-0-alpine-fat as build

RUN apk update
RUN apk add openssl
RUN apk add openssl-dev

RUN  luarocks install penlight
RUN  luarocks install luaossl
RUN  luarocks install lua-resty-jwt



FROM openresty/openresty:alpine

WORKDIR /var/www/html

COPY --from=build  /usr/local/openresty/luajit/share/lua/5.1 /usr/local/openresty/luajit/share/lua/5.1

COPY ./ /var/www/html
COPY config/env.docker.lua /var/www/html/config/env.lua

COPY deploy/nginx/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY deploy/nginx/nginx.vh.default.conf /etc/nginx/conf.d/default.conf


RUN mkdir -p /tmp/cache/nginx

ADD deploy/nginx/docker-openresty-entrypoint /usr/local/bin/
ENTRYPOINT [ "/usr/local/bin/docker-openresty-entrypoint" ]

CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]