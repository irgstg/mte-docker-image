FROM ubuntu:21.04

# TODO: replace this exe_name thing to something normal

# WORKDIR serves as the location of the kernel and buildroot
ENV	WORKDIR	/workdir
# RSC_DIR is the copy of local resources/ dir
ENV	RSC_DIR /resources

# Installing packges.
RUN     apt update && \
        DEBIAN_FRONTEND=noninteractive apt install -y -q --no-install-recommends \
        make cmake gcc g++ git clang qemu-system-aarch64 wget patch binutils-aarch64-linux-gnu gcc-aarch64-linux-gnu \
	binutils build-essential gzip bzip2 perl tar cpio unzip rsync file python python3 qemu-system-x86 ssh \
        libpixman-1-dev build-essential libncurses-dev bc bison flex libssl-dev libelf-dev binutils-aarch64-linux-gnu gcc-aarch64-linux-gnu && \
        apt -y autoremove && \
        apt clean autoclean && \
        rm -rf /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*

RUN	echo "check_certificate = off" >> ~/.wgetrc

# Kernel compilation
RUN	mkdir -p $WORKDIR && \
	cd $WORKDIR && \
	wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.13.tar.xz && \
	tar xf linux-5.13.tar.xz && mv linux-5.13 kernel && cd kernel && \
	CC=clang ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- make defconfig && \
	CC=clang ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- make -j$(nproc) Image

ENV	KIMAGE $WORKDIR/kernel/arch/arm64/boot/Image

COPY	resources/ $RSC_DIR

# Generating FS with buildroot, patching GLIBC.
RUN	cd $WORKDIR && GIT_SSL_NO_VERIFY=true git clone https://github.com/buildroot/buildroot.git --depth=1 && \
	cd buildroot && \
	patch -p1 < $RSC_DIR/0001-package-glibc-adding-support-for-glibc-with-MTE.patch && \
	cp $RSC_DIR/buildroot.config .config && yes "" | make oldconfig && \
	make -j$(nproc)  

# Compiling the C code to aarch64
# There was an issue installing g++-multilib as part of the beggining apt installations, some collision.
# For some reason, the next flow solves it.
RUN	DEBIAN_FRONTEND=noninteractive apt -y autoremove && \
	DEBIAN_FRONTEND=noninteractiv apt -y install gcc-aarch64-linux-gnu && apt -y autoremove
RUN	apt -y install g++-multilib
RUN	apt -y install gcc-aarch64-linux-gnu
RUN	clang -target aarch64-linux-gnu -march=armv8.5a+memtag -fsanitize=memtag $RSC_DIR/main.c -o $RSC_DIR/exe_name

# Copy the executable to the FS, changing ssh configurations
RUN	cp $RSC_DIR/exe_name $WORKDIR/buildroot/output/target/exe_name && \
	echo "PermitRootLogin yes\n" >> $WORKDIR/buildroot/output/target/etc/ssh/sshd_config && \
	echo "PasswordAuthentication yes\n" >> $WORKDIR/buildroot/output/target/etc/ssh/sshd_config && \
	echo "PermitEmptyPasswords yes\n" >> $WORKDIR/buildroot/output/target/etc/ssh/sshd_config && \
	echo "ClientAliveInterval 420\n" >> $WORKDIR/buildroot/output/target/etc/ssh/sshd_config && \
	sed -i "s#^root:\*:#root::#g" $WORKDIR/buildroot/output/target/etc/shadow && \ 
	cd $WORKDIR/buildroot && make

ENV	FSIMAGE $WORKDIR/buildroot/output/images/rootfs.ext3

