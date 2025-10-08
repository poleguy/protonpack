# d3xx drivers
wget https://ftdichip.com/wp-content/uploads/2024/07/libftd3xx-linux-x86_64-1.0.16.tgz

tar -xvf libftd3xx-linux-x86_64-1.0.16.tgz -C .

## see README.pdf for install steps

sudo rm /usr/local/lib/libftd3xx.so
sudo cp libftd3xx.so /usr/local/lib/
sudo cp libftd3xx.so.* /usr/local/lib/
sudo cp 51-ftd3xx.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
# build
gcc ft600_stream.c -o ft600_stream -lftd3xx -L/usr/local/lib -Ilinux-x86_64/


# run
./ft600_stream

# test whole thing
./test_it
