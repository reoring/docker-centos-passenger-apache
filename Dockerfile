FROM centos:7.2.1511

RUN yum -y update
# RUN yum -y groupinstall "Development Tools"
RUN rpm --rebuilddb && yum install -y gcc make gcc-c++ wget perl readline readline-devel zlib zlib-devel curl curl-devel tk-devel openssl-devel gdbm-devel bison git which tar postgresql-contrib postgresql-devel

# Install epel
RUN sed -i '0,/enabled=.*/{s/enabled=.*/enabled=1/}' /etc/yum.repos.d/CentOS-Base.repo
RUN wget http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-8.noarch.rpm && rpm -ivh epel-release-7-8.noarch.rpm
RUN yum update -y

# Install rbenv and ruby-build
RUN git clone https://github.com/sstephenson/rbenv.git /root/.rbenv
RUN git clone https://github.com/sstephenson/ruby-build.git /root/.rbenv/plugins/ruby-build
RUN /root/.rbenv/plugins/ruby-build/install.sh
ENV PATH /root/.rbenv/bin:$PATH
RUN echo 'eval "$(rbenv init -)"' >> /etc/profile.d/rbenv.sh # or /etc/profile
RUN echo 'eval "$(rbenv init -)"' >> .bashrc
# Install multiple versions of ruby
ENV CONFIGURE_OPTS --disable-install-doc
ADD ./versions.txt /root/versions.txt
RUN xargs -L 1 rbenv install < /root/versions.txt

# Install Bundler for each version of ruby
RUN echo 'gem: --no-rdoc --no-ri' >> /.gemrc
RUN bash -l -c 'for v in $(cat /root/versions.txt); do rbenv global $v; gem install bundler rails pg therubyracer passenger; done'

# LibYAML
ADD yaml-0.1.7.tar.gz /usr/local/src
RUN cd /usr/local/src/yaml-0.1.7/ && ./configure --prefix=/usr/local && make -j8 && make install

# APR
ADD apr-1.5.2.tar.gz /usr/local/src
RUN cd /usr/local/src/apr-1.5.2/ && ./configure --prefix=/usr/local/apr-1.5.2 && make -j8 && make install

# APR-util
ADD apr-util-1.5.4.tar.gz /usr/local/src
RUN cd /usr/local/src/apr-util-1.5.4 && ./configure --prefix=/usr/local/apr-util --with-apr=/usr/local/apr-1.5.2 && make -j8 && make install

# PCRE
ADD pcre-8.39.tar.gz /usr/local/src
RUN cd /usr/local/src/pcre-8.39 && ./configure --prefix=/usr/local/pcre && make -j8 && make install

# Apache
ADD httpd-2.4.23.tar.gz /usr/local/src
RUN cd /usr/local/src/httpd-2.4.23 && ./configure --enable-shared=max --enable-module=all --enable-systemd --prefix=/usr/local/apache --with-apr=/usr/local/apr-1.5.2 --with-apr-util=/usr/local/apr-util --with-pcre=/usr/local/pcre && make -j8 && make install

RUN echo 'LD_LIBRARY_PATH=/usr/local/pgsql/lib:/usr/local/apr-1.5.2/lib:/usr/local/apr-util/lib:/usr/local/pcre/lib' >> /etc/profile.d/lib_common_env.sh
RUN echo 'export LD_LIBRARY_PATH' >> /etc/profile.d/lib_common_env.sh
RUN echo 'PATH=/usr/local/lib:/usr/local/pgsql/bin:$PATH' >> /etc/profile.d/lib_common_env.sh
RUN echo 'export PATH' >> /etc/profile.d/lib_common_env.sh
RUN echo 'MANPATH=/usr/local/pgsql/man:$MANPATH' >> /etc/profile.d/lib_common_env.sh
RUN echo 'export MANPATH' >> /etc/profile.d/lib_common_env.sh

RUN groupadd apache
RUN useradd -g apache apache
RUN sed -i -e 's/User daemon/User apache/g' /usr/local/apache/conf/httpd.conf
RUN sed -i -e 's/Group daemon/Group apache/g' /usr/local/apache/conf/httpd.conf
RUN chown -R apache.apache /usr/local/apache/htdocs/

# Install passenger for apache
RUN bash --login -c "export APU_CONFIG=/usr/local/apr-util/bin/apu-1-config \
export APR_CONFIG=/usr/local/apr-1.5.2/bin/apr-1-config \
export HTTPD=/usr/local/apache/bin/httpd \
export APXS2=/usr/local/apache/bin/apxs \
rbenv global 2.3.1; passenger-install-apache2-module -a"
