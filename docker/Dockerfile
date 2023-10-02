FROM raetro/quartus:17.1 as base

ARG GOPATH=/gocode

ENV GOPATH=${GOPATH}

#####

FROM base as install

ARG GO_TARBALL=go1.19.13.linux-amd64.tar.gz

# install Go 1.19
RUN curl -L https://go.dev/dl/${GO_TARBALL} -o /tmp/${GO_TARBALL} && \
	tar -C /usr/local -xzf /tmp/${GO_TARBALL} && \
	rm /tmp/${GO_TARBALL}

#####

FROM base

# add go and /opt/intelFPGA_lite/quartus/bin to path
ENV PATH=/usr/local/go/bin:/opt/intelFPGA_lite/quartus/bin/:$PATH

COPY --from=install /usr/local/go /usr/local/go

# stretch has been moved to archive.debian.org
# I can’t find stretch-updates there
RUN sed -E 's/(deb|security).debian.org/archive.debian.org/' < /etc/apt/sources.list \
	| grep -v stretch-updates > /etc/apt/sources.list.new && \
	mv /etc/apt/sources.list.new /etc/apt/sources.list
RUN apt-get update && apt-get install -y patch g++ gawk && rm -r /var/lib/apt/lists/*

# symlink Quartus into /opt/intelFPGA_lite for jtcore to find it
RUN ln -s ${QUARTUS_PATH} /opt/intelFPGA_lite
