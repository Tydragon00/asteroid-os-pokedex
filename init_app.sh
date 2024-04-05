cd init
mkdir images
go run main.go
cd ..  
mv init/pokemon.db src/db/
mv init/images src/