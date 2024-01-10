#device: ssh root@$ssh_address
ssh_address="192.168.2.15"
#remove build
rm -rf build
#build ipk
export CMAKE_PROGRAM_PATH=/usr/local/oecore-x86_64/sysroots/armv7vehf-neon-oe-linux-gnueabi/usr/bin/
source /usr/local/oecore-x86_64/environment-setup-armv7vehf-neon-oe-linux-gnueabi
cmake -B build -DCMAKE_INSTALL_PREFIX:PATH=/usr
cmake --build build --target package

#delete ipk 
ssh root@$ssh_address "opkg remove poke-dex"
#transfer ipk
scp build/poke-dex*.ipk root@$ssh_address:.
#install new ipk
ssh root@$ssh_address "opkg install poke-dex*.ipk"