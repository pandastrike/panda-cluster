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
RUN pacman -S --noconfirm git openssh wget vim tmux

#======================================
# Install Node v0.11+ and CoffeeScript
#======================================
# We need the powerful concurrency technologies that are only available in the
# currently unstable Node v0.11. We will have to jump through a couple extra
# hoops until it's released via package manager.

# Install nvm from source.
RUN git clone https://github.com/creationix/nvm.git ~/.nvm && \
cd ~/.nvm && \
git checkout `git describe --abbrev=0 --tags`

# To use the commands nvm and npm, we need to prefix those commands with a source
# command, followed by "nvm use v0.11" (starting after this "nvm install" command, of course).
RUN source ~/.nvm/nvm.sh && nvm install 0.11

# Now install CoffeeScript.
RUN source ~/.nvm/nvm.sh && nvm use 0.11 && \
npm install -g coffee-script
#================================

# Pull the Kick repo from GitHub.
RUN git clone https://github.com/pandastrike/panda-cluster-kick.git

# Install all other modules / dependencies.
RUN cd panda-cluster-kick && \
source ~/.nvm/nvm.sh && nvm use 0.11 && \
npm install
