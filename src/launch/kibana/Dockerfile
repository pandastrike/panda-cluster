FROM base/archlinux
MAINTAINER David Harper (david@pandastrike.com)
#===============================================================================
# Kibana 4
#===============================================================================
# This Dockerfile describes a the data vizualization tool Kibana.  This file
# will install Kibana 4 Beta 3.

RUN pacman -Syu --noconfirm
RUN pacman-db-upgrade
RUN pacman -S --noconfirm jre7-openjdk-headless wget

# Install Elasticsearch 1.4.2
RUN mkdir downloads && cd downloads && \
wget https://download.elasticsearch.org/kibana/kibana/kibana-4.0.0-beta3.tar.gz && \
tar -xvf kibana-4.0.0-beta3.tar.gz && \
mv kibana-4.0.0-beta3 ~/.

# Clean up the download directory.
RUN rm -rf downloads
