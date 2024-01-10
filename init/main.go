package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	_ "github.com/mattn/go-sqlite3"
	"golang.org/x/text/cases"
	"golang.org/x/text/language"
)

type PokemonGenerationResponse struct {
	Count  int    `json:"count"`
	Name   string `json:"name"`
	Result []struct {
		Name string `json:"name"`
		URL  string `json:"url"`
	} `json:"results"`
}
type PokemonListResponse struct {
	Result []struct {
		Name string `json:"name"`
		URL  string `json:"url"`
	} `json:"pokemon_species"`
}
type PokemonResponse struct {
	ID    int    `json:"id"`
	Name  string `json:"name"`
	Types []struct {
		Type struct {
			Name string `json:"name"`
			URL  string `json:"url"`
		} `json:"type"`
		URL string `json:"url"`
	} `json:"types"`
	Sprites struct {
		Other struct {
			ArtWork struct {
				Image string `json:"front_default"`
			} `json:"official-artwork"`
		} `json:"other"`
	} `json:"sprites"`
}

type PokemonGeneration struct {
	ID   int
	Name string
}
type PokemonUrl struct {
	ID   int
	Name string
}
type PokemonDetail struct {
	ID       int
	Name     string
	Types    []string
	ImageUrl string
}

type PokemonDB struct {
	ID        int
	Name      string
	ImagePath string
	Types     string

	//generation
	GenerationName string
	GenerationID   int
}

func main() {
	db, err := sql.Open("sqlite3", "./pokemon.db")
	if err != nil {
		return
	}
	defer db.Close()

	_, err = db.Exec(`CREATE TABLE IF NOT EXISTS Pokemons (
		ID INTEGER PRIMARY KEY,
		Name TEXT,
		ImagePath TEXT,
		Types TEXT,
		GenerationName TEXT,
		GenerationID INTEGER
	)`)
	if err != nil {
		return
	}

	pokemons := []PokemonDB{}
	generationList := getGenerationList()
	for _, gen := range generationList {
		pokemonList := getPokemonList(gen)
		for _, pk := range pokemonList {
			fmt.Println(pk.Name)
			pokemonDetail := getPokemon(pk)
			createPokemonDB(&pokemons, pokemonDetail, gen)
		}
	}

	stmt, err := db.Prepare(`INSERT INTO Pokemons (ID, Name, ImagePath, Types, GenerationName, GenerationID) VALUES (?, ?, ?, ?, ?, ?)`)
	if err != nil {
		return
	}
	defer stmt.Close()

	for _, pokemon := range pokemons {
		_, err = stmt.Exec(pokemon.ID, pokemon.Name, pokemon.ImagePath, pokemon.Types, pokemon.GenerationName, pokemon.GenerationID)
		if err != nil {
			return
		}
	}
}
func getGenerationList() (res []PokemonGeneration) {
	url := "https://pokeapi.co/api/v2/generation/"
	resp, err := http.Get(url)
	if err != nil {
		log.Fatal(err)
	}
	defer resp.Body.Close()

	var generationData PokemonGenerationResponse
	err = json.NewDecoder(resp.Body).Decode(&generationData)
	if err != nil {
		log.Fatal(err)
	}
	generationList := []PokemonGeneration{}

	for id, gr := range generationData.Result {
		generationList = append(generationList, PokemonGeneration{
			Name: gr.Name,
			ID:   id + 1,
		})
	}
	return generationList
}
func getPokemonList(gen PokemonGeneration) (res []PokemonUrl) {
	url := fmt.Sprintf("https://pokeapi.co/api/v2/generation/%d", gen.ID)
	resp, err := http.Get(url)
	if err != nil {
		log.Fatal("Errore nella richiesta HTTP: ", err)
	}
	defer resp.Body.Close()

	var pokemonData PokemonListResponse
	err = json.NewDecoder(resp.Body).Decode(&pokemonData)
	if err != nil {
		log.Fatal(err)
	}
	pokemonUrlList := []PokemonUrl{}

	for _, pk := range pokemonData.Result {
		parts := strings.Split(pk.URL, "/")
		pokemonNumberStr := parts[len(parts)-2]
		pokemonNumber, err := strconv.Atoi(pokemonNumberStr)
		if err != nil {
			return
		}
		pokemonUrlList = append(pokemonUrlList, PokemonUrl{
			Name: pk.Name,
			ID:   pokemonNumber,
		})
	}
	return pokemonUrlList
}
func getPokemon(pokemon PokemonUrl) (res PokemonDetail) {
	url := fmt.Sprintf("https://pokeapi.co/api/v2/pokemon/%d", pokemon.ID)
	resp, err := http.Get(url)
	if err != nil {
		log.Fatal(err)
	}
	defer resp.Body.Close()

	var pokemonData PokemonResponse
	err = json.NewDecoder(resp.Body).Decode(&pokemonData)
	if err != nil {
		log.Fatal(err)
	}
	types := []string{}
	for _, t := range pokemonData.Types {
		types = append(types, t.Type.Name)

	}
	pokemonDetail := PokemonDetail{
		ID:       pokemonData.ID,
		Name:     pokemonData.Name,
		ImageUrl: pokemonData.Sprites.Other.ArtWork.Image,
		Types:    types,
	}

	return pokemonDetail
}

func createPokemonDB(pokemonListForDB *[]PokemonDB, pokemonDetail PokemonDetail, gen PokemonGeneration) {
	for i, t := range pokemonDetail.Types {
		pokemonDetail.Types[i] = cases.Title(language.Und).String(t)
	}
	types := strings.Join(pokemonDetail.Types, ",")
	imagePath, _ := downloadImage(pokemonDetail.ImageUrl)
	pokemonToAdd := PokemonDB{
		ID:             pokemonDetail.ID,
		Name:           cases.Title(language.Und).String(pokemonDetail.Name),
		Types:          types,
		ImagePath:      imagePath,
		GenerationName: strings.ToUpper(gen.Name),
		GenerationID:   gen.ID,
	}
	*pokemonListForDB = append(*pokemonListForDB, pokemonToAdd)
}

func downloadImage(url string) (path string, err error) {
	folder := "images"
	response, err := http.Get(url)
	if err != nil {
		return "", err
	}
	defer response.Body.Close()

	if response.StatusCode != http.StatusOK {
		return "", err
	}

	fileURLParts := strings.Split(url, "/")
	fileName := fileURLParts[len(fileURLParts)-1]

	destPath := filepath.Join(folder, fileName)

	file, err := os.Create(destPath)
	if err != nil {
		return "", err
	}
	defer file.Close()

	_, err = io.Copy(file, response.Body)
	if err != nil {
		return "", err
	}

	return "images/" + fileName, nil
}
