FROM debian:11-slim
ENV SMVERSION 1.11

RUN apt-get update -y \
    && apt-get install -y wget git lib32stdc++6 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN mkdir /runscripts /get5 /get5_src /get5_build
COPY dockerrunscript.sh /runscripts
WORKDIR /get5

ENV SMPACKAGE http://sourcemod.net/latest.php?os=linux&version=${SMVERSION}
RUN wget ${SMPACKAGE} -O - | tar -xz
RUN chmod +x /get5/addons/sourcemod/scripting/spcomp
ENV PATH "$PATH:/get5/addons/sourcemod/scripting"
WORKDIR /get5/addons/sourcemod/scripting/include
RUN wget https://raw.githubusercontent.com/hexa-core-eu/SteamWorks/main/Pawn/includes/SteamWorks.inc
WORKDIR /get5

ENTRYPOINT ["/runscripts/dockerrunscript.sh"]
