FROM base/archlinux
MAINTAINER David Harper (david@pandastrike.com)
#===============================================================================
# Panda-Cluster: Hook Server
#===============================================================================
# This Dockerfile describes a hook-server tailored to act upon an app running
# the CoreOS stack.  Hook-servers contain "bare" git repositories with one or
# more githooks, scripts you trigger with git commands.

# Hook-Server & CoreOS Requirements: (1) git, (2) fleetctl
# Install requirements, a couple dependencies, and some tools that make life easier.
RUN pacman -Syu --noconfirm
RUN pacman-db-upgrade
RUN pacman -S --noconfirm git openssh wget vim tmux

# On Archlinux, fleet is only available as an AUR community package, so we'll have
# to jump through a few extra hoops.  Download the AUR package and place the
# executables into our $PATH.
RUN mkdir aur-packages && cd aur-packages && \
  wget https://github.com/coreos/fleet/releases/download/v0.8.3/fleet-v0.8.3-linux-amd64.tar.gz && \
  tar -xvf fleet-v0.8.3-linux-amd64.tar.gz && \
  cd fleet-v0.8.3-linux-amd64 && \
  mv fleetctl /usr/bin/. && mv fleetd /usr/bin/.

# Clean up the download directory.
RUN rm -rf aur-packages

# Create directory to hold SSH data
RUN mkdir .ssh  && \
  touch .ssh/known_hosts  && touch .ssh/authorized_keys

# Add a configuration file so the hook-server allows agent-forwarding and isn't picky
# about connecting to wherever we ask.
RUN echo "Host *" >> .ssh/config  && \
  echo "  ForwardAgent yes "  >> .ssh/config  && \
  echo "StrictHostKeyChecking no" >> .ssh/config 

# Add a dummy Node server that keeps the Docker container running.  In truth, we
# will rely on SSH and git to handle authorization, detection, and execution.
# However, packaging this in a container allows us to provide dependencies that
# would otherwise be difficult to obtain on the bare machine running CoreOS (CoreOS is notoriously
# lean and only allows additional software to run within Docker containers).
RUN pacman -S --noconfirm nodejs
RUN npm install -g coffee-script
# RUN echo "http = require 'http'" >> dummy.coffee && \
#     echo "http.createServer().listen(80)" >> dummy.coffee && \
#     echo "console.log 'Dummy is online.'" >> dummy.coffee
