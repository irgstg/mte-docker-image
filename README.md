## Instructions
### Building the docker image

Clone the repo and build the docker image:

`git clone https://github.com/irgstg/mte-docker-image.git` 

`cd  mte-docker-image`

`sudo docker build -t mte_image .`

### Running the container, and a sample executable
Running the container:

`sudo docker run -it mte_image /bin/bash`

When inside the container, you can run QEMU:

`qemu-system-aarch64 -machine virt,mte=on -cpu max -kernel $KIMAGE -hda $FSIMAGE -m 2G -display none -serial stdio -append "root=/dev/vda"`

Run the basic executable, generated from `resources/main.c`:

`GLIBC_TUNABLES=glibc.mem.tagging=1 /exe_name`

`SIGSEGV` should be on it's way...

### Debugging with gdbserver (on host)

buildroot generates cross debugger, which can be attached via gdbserver.

Run qemu in the background, forwards two ports:

`qemu-system-aarch64 -machine virt,mte=on -cpu max -kernel $KIMAGE -hda $FSIMAGE -m 2G -display none -serial stdio -append "root=/dev/vda" -net user,hostfwd=tcp::2000-:2000,hostfwd=tcp::10023-:22 -net nic </dev/null &>/dev/null &`

run gdbserver via ssh:

`ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o IdentitiesOnly=yes -p 10023 root@localhost gdbserver localhost:2000 /exe_name </dev/null &>/dev/null & `

Run hosts gdb:

`$WORKDIR/buildroot/output/host/bin/aarch64-buildroot-linux-gnu-gdb $RSC_DIR/exe_name`

Attach to guests gdbserver:

`target remote localhost:2000`
