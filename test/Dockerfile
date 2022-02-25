FROM reitzig/texlive-base:2021.5

RUN tlmgr update --self --repository https://mirror.mwt.me/ctan/systems/texlive/tlnet

RUN echo "http://dl-cdn.alpinelinux.org/alpine/v3.9/main" >> /etc/apk/repositories && \
    echo "http://dl-cdn.alpinelinux.org/alpine/v3.9/community" >> /etc/apk/repositories && \
    apk update && \
# package versions identified via https://pkgs.alpinelinux.org/packages?name=ruby-io-*&branch=v3.9
    apk add --no-cache --update 'ruby<2.6.0' 'ruby-bundler=2.0.2-r0' 'ruby-ffi=1.9.25-r0' 'ruby-io-console<2.6.0' 'ruby-json=2.5.9-r0' 'ruby-rdoc=2.5.9-r0'

COPY test/Texlivefile /work/src

RUN xargs tlmgr install --repository https://mirror.mwt.me/ctan/systems/texlive/tlnet < "/work/src/Texlivefile" && \
    sha256sum "/work/src/Texlivefile" > "/work/tmp/Texlivefile.sha"

COPY . /repo

RUN cd /repo && \
    bundle update --bundler && \
    bundle install

COPY . /ltx2any
