FROM base/archlinux
MAINTAINER David Harper (david@pandastrike.com)
#===============================================================================
# SkyDNS
#===============================================================================
# This Dockerfile is part of the PandaCluster project. It specifies a container running
# SkyDNS, a private DNS service we use to find services in our CoreOS cluster.
# It's great because it keeps track of all the moving parts with human-friendly names.


#============================================
# INSTALLATION
#============================================

# Update Arch pacman
RUN pacman -Syu --noconfirm
RUN pacman-db-upgrade

# SkyDNS is powered by Google's Go.  Install Go, its dependancies git and
# mercurial, and utilities that are useful to have for debugging.
RUN pacman -S --noconfirm go git mercurial dnsutils tmux net-tools socat lsof tree vim
RUN mkdir go


# Now install SkyDNS.  This builds a binary executable.
RUN export GOPATH=/go && go get github.com/skynetservices/skydns
RUN cd go/src/github.com/skynetservices/skydns && \
    export GOPATH=/go && go build -v


# Move the binary executable to the top-level of the container so it is easy to call.
RUN cp go/src/github.com/skynetservices/skydns/skydns .

#============================================
# START
#============================================
# We should not start SkyDNS here directly because we need to feed in configuration
# data at runtime inside the *.service file.
