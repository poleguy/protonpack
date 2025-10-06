# d3xx drivers
https://ftdichip.com/wp-content/uploads/2024/07/libftd3xx-linux-x86_64-1.0.16.tgz

tar -xvf ~/Downloads/libftd3xx-linux-x86_64-1.0.16.tgz -C .

# build
gcc ft600_stream.c -o ft600_stream -lftd3xx -L/usr/local/lib -Ilinux-x86_64/


# run
sudo ./ft600_stream
