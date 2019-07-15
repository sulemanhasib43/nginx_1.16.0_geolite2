FROM ubuntu:18.04

MAINTAINER suleman.hasib@gmail.com

# Install required packages
RUN apt-get update && apt-get install -y git vim wget gcc g++ make software-properties-common cron

# Install libmaxminddb
RUN add-apt-repository ppa:maxmind/ppa \
	&& apt update \
	&& apt install libmaxminddb0 libmaxminddb-dev mmdb-bin

# create nginx user/group first, to be consistent throughout docker variants
RUN set -x \
    && addgroup --system nginx \
    && adduser --system --disabled-login --ingroup nginx --no-create-home --gecos "nginx user" --shell /bin/false nginx

# PCRE – Supports regular expressions. Required by the NGINX Core and Rewrite modules. 
RUN wget ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-8.42.tar.gz \
	&& tar -zxf pcre-8.42.tar.gz \
	&& cd pcre-8.42 && ./configure \
	&& make \
	&& make install \
	&& cd ../

# zlib – Supports header compression. Required by the NGINX Gzip module.
RUN wget http://zlib.net/zlib-1.2.11.tar.gz \
	&& tar -zxf zlib-1.2.11.tar.gz \
	&& cd zlib-1.2.11 \
	&& ./configure \
	&& make \
	&& make install \
	&& cd ../

# OpenSSL – Supports the HTTPS protocol. Required by the NGINX SSL module and others.
RUN wget http://www.openssl.org/source/openssl-1.1.1b.tar.gz \
	&& tar -zxf openssl-1.1.1b.tar.gz \
	&& cd openssl-1.1.1b \
	&& ./Configure linux-x86_64 --prefix=/usr \
	&& make \
	&& make install && cd ../

# Create Nginx Directory Structure
RUN mkdir -p /var/cache/nginx/{client_temp,proxy_temp,fastcgi_temp,uwsgi_temp,scgi_temp}

# Downloading and Installing NGiNX from Source
RUN wget http://nginx.org/download/nginx-1.16.0.tar.gz \
	&& tar zxf nginx-1.16.0.tar.gz \
	&& cd nginx-1.16.0 \
	&& git clone https://github.com/leev/ngx_http_geoip2_module.git ./geoip2 \
	# Configuring the Build Options
	&& ./configure \
	--add-dynamic-module=geoip2 \
	--prefix=/etc/nginx \
	--sbin-path=/usr/sbin/nginx \
	--modules-path=/usr/lib/nginx/modules \
	--conf-path=/etc/nginx/nginx.conf \
	--error-log-path=/var/log/nginx/error.log \
	--http-log-path=/var/log/nginx/access.log \
	--pid-path=/var/run/nginx.pid \
	--lock-path=/var/run/nginx.lock \
	--http-client-body-temp-path=/var/cache/nginx/client_temp \
	--http-proxy-temp-path=/var/cache/nginx/proxy_temp \
	--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
	--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
	--http-scgi-temp-path=/var/cache/nginx/scgi_temp \
	--user=nginx \
	--group=nginx \
	--with-compat \
	--with-file-aio \
	--with-threads \
	--with-http_addition_module \
	--with-http_auth_request_module \
	--with-http_dav_module \
	--with-http_flv_module \
	--with-http_gunzip_module \
	--with-http_gzip_static_module \
	--with-http_mp4_module \
	--with-http_random_index_module \
	--with-http_realip_module \
	--with-http_secure_link_module \
	--with-http_slice_module \
	--with-http_ssl_module \
	--with-http_stub_status_module \
	--with-http_sub_module \
	--with-http_v2_module \
	--with-mail \
	--with-mail_ssl_module \
	--with-stream \
	--with-stream_realip_module \
	--with-stream_ssl_module \
	--with-stream_ssl_preread_module \
	--with-pcre=../pcre-8.42 \
	--with-zlib=../zlib-1.2.11 \
	--with-mail=dynamic \
	# Install NGiNX
	&& make \
	&& make install

# Copy Nginx Modules
RUN mkdir /etc/nginx/modules \
	&& cp /nginx-1.16.0/objs/*.so /etc/nginx/modules/

# Copy Nginx Config which load geoip2 module
COPY nginx.conf /etc/nginx/nginx.conf

# Download Maxmind GeoLite2 DB
RUN cd /etc/nginx/ \
	&& wget https://geolite.maxmind.com/download/geoip/database/GeoLite2-Country.tar.gz \
	&& tar --strip=1 --wildcards -xvf GeoLite2-Country.tar.gz GeoLite2-Country_*/GeoLite2-Country.mmdb \
	&& rm /etc/nginx/GeoLite2-Country.tar.gz

# Copy CRONTAB
COPY crontab /etc/cron.d/geoip2-cron
RUN chmod 0644 /etc/cron.d/geoip2-cron \
	&& crontab /etc/cron.d/geoip2-cron \
	&& touch /var/log/cron.log

# Cleanup
RUN apt-get purge -y --auto-remove \
	&& apt-get autoclean \
	&& rm -r /pcre-8.42.tar.gz /zlib-1.2.11.tar.gz /openssl-1.1.1b.tar.gz 

EXPOSE 80

STOPSIGNAL SIGTERM

CMD ["/usr/sbin/nginx", "-g", "daemon off;"]