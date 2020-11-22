FROM debian:10
MAINTAINER Alexander Volz (Alexander@volzit.de)

ENV SMVERSION 1.10

ENV _clean="rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*"
ENV _apt_clean="eval apt-get clean && $_clean"

# Install support pkgs
RUN apt-get update -qqy && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl wget nano net-tools gnupg2 git lib32stdc++6 python \
    python-pip tar bash  && $_apt_clean

RUN mkdir /get5
RUN mkdir /runscripts
RUN mkdir /get5src
COPY dockerrunscript.sh /runscripts
WORKDIR /get5

RUN git clone https://github.com/splewis/sm-builder
WORKDIR /get5/sm-builder
RUN pip install --user -r requirements.txt
RUN python setup.py install --prefix=~/.local
WORKDIR /get5

ENV SMPACKAGE http://sourcemod.net/latest.php?os=linux&version=${SMVERSION}
RUN wget -q ${SMPACKAGE}
RUN tar xfz $(basename ${SMPACKAGE})
RUN chmod +x /get5/addons/sourcemod/scripting/spcomp
ENV PATH "$PATH:/get5/addons/sourcemod/scripting:/root/.local/bin"
WORKDIR /get5/addons/sourcemod/scripting/include
RUN wget https://raw.githubusercontent.com/KyleSanderson/SteamWorks/master/Pawn/includes/SteamWorks.inc
WORKDIR /get5

VOLUME /get5/builds
VOLUME /get5src
CMD ["/runscripts/dockerrunscript.sh"]
