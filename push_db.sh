#device: ssh root@$ssh_address
ssh_address="192.168.2.15"
scp src/db/pokemon.db ceres@$ssh_address:.