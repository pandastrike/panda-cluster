FROM base/archlinux
MAINTAINER David Harper (david@pandastrike.com)
#===============================================================================
# Kick Server - Huxley
#===============================================================================
# This Dockerfile describes a kick server for a Huxley cluster. (short for sidekick).
# It's a primative, meta API server that allows the cluster to alter itself
# independently of a remote actor.  The Kick server also contains the library of
# all Huxley mixins.

# Install requirements and some tools that make life easier.
RUN pacman -Syu --noconfirm
RUN pacman-db-upgrade
RUN pacman -S --noconfirm git openssh wget vim tmux nodejs

# Install CoffeeScript.
RUN npm install -g coffee-script

# Pull the Kick repo from GitHub.
RUN git clone https://github.com/pandastrike/panda-kick.git

# Install all other modules / dependencies.
RUN cd panda-kick && npm install
