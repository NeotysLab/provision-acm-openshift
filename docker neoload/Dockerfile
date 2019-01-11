FROM anapsix/alpine-java as builder

ARG BUILD_BRANCH=stable%2Fv6_8_x
ARG BUILD_NL_MINOR_VERSION_DOT=6.8
ARG BUILD_NUMBER=16
ARG BUILD_NL_VERSION=6_8_0

ADD https://www.neotys.com/redirect/redirect.php?product=neoload&target=direct-download&os=linux&archi=x64&version=latest neoload.sh

RUN sh /neoload.sh -q -dir /neoload -Vsys.installationTypeId=Controller -Vsys.component.Common\$Boolean=true -Vsys.component.Controller\$Boolean=true


FROM alpine:3.7

ENV user=jenkins
ENV group=jenkins
ENV uid=10000
ENV gid=10000

ENV GLIBC_REPO=https://github.com/sgerrand/alpine-pkg-glibc \
    GLIBC_VERSION=2.27-r0 \
    LANG=C.UTF-8 \
    LOG_ALSO_TO_CONSOLE=true

RUN set -ex && \
    apk -U upgrade && \
    apk add libstdc++ curl ca-certificates bash && \
    for pkg in glibc-${GLIBC_VERSION} glibc-bin-${GLIBC_VERSION} glibc-i18n-${GLIBC_VERSION}; do curl -sSL ${GLIBC_REPO}/releases/download/${GLIBC_VERSION}/${pkg}.apk -o /tmp/${pkg}.apk; done && \
    apk add --allow-untrusted /tmp/*.apk && \
    rm -v /tmp/*.apk && \
    ( /usr/glibc-compat/bin/localedef --force --inputfile POSIX --charmap UTF-8 C.UTF-8 || true ) && \
    echo "export LANG=C.UTF-8" > /etc/profile.d/locale.sh && \
    /usr/glibc-compat/sbin/ldconfig /lib /usr/glibc-compat/lib && \
    apk del curl glibc-i18n && \
    addgroup -g ${gid} -S ${group} && \
    adduser -S ${user}  -u ${uid} -G  ${group} && \
    chmod g+w /etc/passwd && \
    chmod -R u+x /home/${user} && \
    chgrp -R 0 /home/${user} && \
    chmod -R g=u /home/${user}

COPY --chown=jenkins:jenkins --from=builder /neoload /neoload

USER ${user}

ENTRYPOINT ["/bin/sh"]