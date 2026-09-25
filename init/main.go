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
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	_ "github.com/mattn/go-sqlite3"
	"golang.org/x/text/cases"
	"golang.org/x/text/language"
)

const (
	apiBase      = "https://pokeapi.co/api/v2"
	maxAttempts  = 3
	workerCount  = 8
	fallbackLang = "en"
)

type namedResource struct {
	Name string `json:"name"`
	URL  string `json:"url"`
}

type localizedName struct {
	Name     string `json:"name"`
	Language struct {
		Name string `json:"name"`
	} `json:"language"`
}

type generationListResponse struct {
	Results []namedResource `json:"results"`
}

type generationResponse struct {
	ID             int             `json:"id"`
	Name           string          `json:"name"`
	Names          []localizedName `json:"names"`
	PokemonSpecies []namedResource `json:"pokemon_species"`
}

type pokemonResponse struct {
	ID     int    `json:"id"`
	Name   string `json:"name"`
	Height int    `json:"height"`
	Weight int    `json:"weight"`
	Types  []struct {
		Type struct {
			Name string `json:"name"`
		} `json:"type"`
	} `json:"types"`
	Stats []struct {
		BaseStat int `json:"base_stat"`
		Stat     struct {
			Name string `json:"name"`
		} `json:"stat"`
	} `json:"stats"`
	Sprites struct {
		Other struct {
			ArtWork struct {
				Image string `json:"front_default"`
			} `json:"official-artwork"`
		} `json:"other"`
	} `json:"sprites"`
}

type speciesResponse struct {
	ID    int             `json:"id"`
	Name  string          `json:"name"`
	Names []localizedName `json:"names"`
	Genera []struct {
		Genus    string `json:"genus"`
		Language struct {
			Name string `json:"name"`
		} `json:"language"`
	} `json:"genera"`
	FlavorTextEntries []struct {
		FlavorText string `json:"flavor_text"`
		Language   struct {
			Name string `json:"name"`
		} `json:"language"`
		Version struct {
			Name string `json:"name"`
		} `json:"version"`
	} `json:"flavor_text_entries"`
}

type pokemonRecord struct {
	ID             int
	Name           string
	ImagePath      string
	Types          string
	GenerationName string
	GenerationID   int
	Height         int
	Weight         int
	Stats          [6]int
	Names          map[string]string
	Flavor         map[string]string
	Genera         map[string]string
}

var statOrder = []string{"hp", "attack", "defense", "special-attack", "special-defense", "speed"}

func main() {
	generationIDs, err := requestedGenerations()
	if err != nil {
		log.Fatal(err)
	}

	records, generationNames, err := collect(generationIDs)
	if err != nil {
		log.Fatal(err)
	}

	if err := writeDatabase(records, generationNames); err != nil {
		log.Fatal(err)
	}

	fmt.Printf("Wrote %d Pokémon\n", len(records))
}

// requestedGenerations returns the generation ids to fetch. By default all
// generations are fetched; POKEDEX_GENERATIONS=1,2 limits the run, which is
// useful while developing.
func requestedGenerations() ([]int, error) {
	raw := strings.TrimSpace(os.Getenv("POKEDEX_GENERATIONS"))
	if raw == "" {
		return nil, nil
	}

	var ids []int
	for _, part := range strings.Split(raw, ",") {
		id, err := strconv.Atoi(strings.TrimSpace(part))
		if err != nil {
			return nil, fmt.Errorf("invalid POKEDEX_GENERATIONS value %q: %w", raw, err)
		}
		ids = append(ids, id)
	}
	return ids, nil
}

// collect fetches every generation and returns the Pokémon records together
// with the localized generation names.
func collect(generationIDs []int) ([]pokemonRecord, map[int]map[string]string, error) {
	if len(generationIDs) == 0 {
		var list generationListResponse
		if err := getJSON(apiBase+"/generation/", &list); err != nil {
			return nil, nil, err
		}
		for i := range list.Results {
			generationIDs = append(generationIDs, i+1)
		}
	}

	generationNames := map[int]map[string]string{}
	type task struct {
		id         int
		generation generationResponse
	}

	var tasks []task
	for _, id := range generationIDs {
		var generation generationResponse
		if err := getJSON(fmt.Sprintf("%s/generation/%d", apiBase, id), &generation); err != nil {
			return nil, nil, err
		}
		generationNames[generation.ID] = localizedMap(generation.Names)
		log.Printf("generation %d: %d species", generation.ID, len(generation.PokemonSpecies))
		for _, species := range generation.PokemonSpecies {
			pokemonID, err := idFromURL(species.URL)
			if err != nil {
				return nil, nil, err
			}
			tasks = append(tasks, task{id: pokemonID, generation: generation})
		}
	}

	records := make([]pokemonRecord, 0, len(tasks))
	var mu sync.Mutex
	var wg sync.WaitGroup
	taskCh := make(chan task)

	for i := 0; i < workerCount; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for t := range taskCh {
				record, err := fetchPokemon(t.id, t.generation)
				if err != nil {
					log.Fatalf("could not fetch Pokémon %d: %v", t.id, err)
				}
				mu.Lock()
				records = append(records, record)
				if len(records)%100 == 0 {
					log.Printf("%d/%d Pokémon", len(records), len(tasks))
				}
				mu.Unlock()
			}
		}()
	}

	for _, t := range tasks {
		taskCh <- t
	}
	close(taskCh)
	wg.Wait()

	sort.Slice(records, func(i, j int) bool { return records[i].ID < records[j].ID })
	return records, generationNames, nil
}

func fetchPokemon(id int, generation generationResponse) (pokemonRecord, error) {
	var pokemon pokemonResponse
	if err := getJSON(fmt.Sprintf("%s/pokemon/%d", apiBase, id), &pokemon); err != nil {
		return pokemonRecord{}, err
	}

	var species speciesResponse
	if err := getJSON(fmt.Sprintf("%s/pokemon-species/%d", apiBase, id), &species); err != nil {
		return pokemonRecord{}, err
	}

	types := make([]string, 0, len(pokemon.Types))
	for _, t := range pokemon.Types {
		types = append(types, cases.Title(language.Und).String(t.Type.Name))
	}

	stats := [6]int{}
	for _, stat := range pokemon.Stats {
		for i, name := range statOrder {
			if stat.Stat.Name == name {
				stats[i] = stat.BaseStat
			}
		}
	}

	imagePath, err := downloadImage(pokemon.Sprites.Other.ArtWork.Image)
	if err != nil {
		return pokemonRecord{}, err
	}

	return pokemonRecord{
		ID:             pokemon.ID,
		Name:           cases.Title(language.Und).String(pokemon.Name),
		ImagePath:      imagePath,
		Types:          strings.Join(types, ","),
		GenerationName: strings.ToUpper(generation.Name),
		GenerationID:   generation.ID,
		Height:         pokemon.Height,
		Weight:         pokemon.Weight,
		Stats:          stats,
		Names:          localizedMap(species.Names),
		Flavor:         latestFlavorTexts(species),
		Genera:         generaMap(species),
	}, nil
}

// localizedMap turns the API's name/genera lists into language -> text maps.
func localizedMap(names []localizedName) map[string]string {
	result := map[string]string{}
	for _, name := range names {
		result[name.Language.Name] = name.Name
	}
	return result
}

func generaMap(species speciesResponse) map[string]string {
	result := map[string]string{}
	for _, genus := range species.Genera {
		result[genus.Language.Name] = genus.Genus
	}
	return result
}

// latestFlavorTexts keeps one flavor text per language, the newest one
// available, and normalizes the form feeds and line breaks the API returns.
func latestFlavorTexts(species speciesResponse) map[string]string {
	result := map[string]string{}
	for _, entry := range species.FlavorTextEntries {
		text := strings.Join(strings.Fields(entry.FlavorText), " ")
		if text == "" {
			continue
		}
		result[entry.Language.Name] = text
	}
	return result
}

func idFromURL(url string) (int, error) {
	parts := strings.Split(strings.TrimRight(url, "/"), "/")
	if len(parts) == 0 {
		return 0, fmt.Errorf("no id in URL %q", url)
	}
	return strconv.Atoi(parts[len(parts)-1])
}

func getJSON(url string, target interface{}) error {
	body, err := get(url)
	if err != nil {
		return err
	}
	defer body.Close()

	return json.NewDecoder(body).Decode(target)
}

// get performs a GET request with retries and returns the response body.
func get(url string) (io.ReadCloser, error) {
	var lastErr error
	for attempt := 1; attempt <= maxAttempts; attempt++ {
		if attempt > 1 {
			time.Sleep(time.Duration(attempt) * time.Second)
		}

		response, err := http.Get(url)
		if err != nil {
			lastErr = err
			continue
		}
		if response.StatusCode != http.StatusOK {
			response.Body.Close()
			lastErr = fmt.Errorf("unexpected status %s for %s", response.Status, url)
			continue
		}
		return response.Body, nil
	}

	return nil, fmt.Errorf("giving up after %d attempts: %w", maxAttempts, lastErr)
}

// downloadImage fetches the official artwork and stores it as a PNG next to the
// database. The path written to the database points at the .webp file that
// init_app.sh generates from it, so both steps have to agree on the base name.
func downloadImage(url string) (string, error) {
	if url == "" {
		return "", fmt.Errorf("no artwork available")
	}

	fileName := filepath.Base(url)
	destPath := filepath.Join("images", fileName)

	body, err := get(url)
	if err != nil {
		return "", err
	}
	defer body.Close()

	file, err := os.Create(destPath)
	if err != nil {
		return "", err
	}

	if _, err := io.Copy(file, body); err != nil {
		file.Close()
		return "", err
	}
	if err := file.Close(); err != nil {
		return "", err
	}

	base := strings.TrimSuffix(fileName, filepath.Ext(fileName))
	return "images/" + base + ".webp", nil
}

func writeDatabase(records []pokemonRecord, generationNames map[int]map[string]string) error {
	db, err := sql.Open("sqlite3", "./pokemon.db")
	if err != nil {
		return err
	}
	defer db.Close()

	statements := []string{
		`CREATE TABLE Pokemons (
			ID INTEGER PRIMARY KEY,
			Name TEXT,
			ImagePath TEXT,
			Types TEXT,
			GenerationName TEXT,
			GenerationID INTEGER,
			Height INTEGER,
			Weight INTEGER,
			HP INTEGER,
			Attack INTEGER,
			Defense INTEGER,
			SpecialAttack INTEGER,
			SpecialDefense INTEGER,
			Speed INTEGER
		)`,
		`CREATE TABLE PokemonNames (
			PokemonID INTEGER,
			Language TEXT,
			Name TEXT,
			PRIMARY KEY (PokemonID, Language)
		)`,
		`CREATE TABLE FlavorTexts (
			PokemonID INTEGER,
			Language TEXT,
			Text TEXT,
			PRIMARY KEY (PokemonID, Language)
		)`,
		`CREATE TABLE Genera (
			PokemonID INTEGER,
			Language TEXT,
			Genus TEXT,
			PRIMARY KEY (PokemonID, Language)
		)`,
		`CREATE TABLE GenerationNames (
			GenerationID INTEGER,
			Language TEXT,
			Name TEXT,
			PRIMARY KEY (GenerationID, Language)
		)`,
		`CREATE INDEX PokemonsGeneration ON Pokemons (GenerationID)`,
		`CREATE INDEX PokemonNamesName ON PokemonNames (Name)`,
	}
	for _, statement := range statements {
		if _, err := db.Exec(statement); err != nil {
			return err
		}
	}

	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	pokemonStatement, err := tx.Prepare(`INSERT INTO Pokemons
		(ID, Name, ImagePath, Types, GenerationName, GenerationID, Height, Weight,
		 HP, Attack, Defense, SpecialAttack, SpecialDefense, Speed)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`)
	if err != nil {
		return err
	}
	defer pokemonStatement.Close()

	nameStatement, err := tx.Prepare(`INSERT INTO PokemonNames (PokemonID, Language, Name) VALUES (?, ?, ?)`)
	if err != nil {
		return err
	}
	defer nameStatement.Close()

	flavorStatement, err := tx.Prepare(`INSERT INTO FlavorTexts (PokemonID, Language, Text) VALUES (?, ?, ?)`)
	if err != nil {
		return err
	}
	defer flavorStatement.Close()

	genusStatement, err := tx.Prepare(`INSERT INTO Genera (PokemonID, Language, Genus) VALUES (?, ?, ?)`)
	if err != nil {
		return err
	}
	defer genusStatement.Close()

	for _, record := range records {
		if _, err := pokemonStatement.Exec(record.ID, record.Name, record.ImagePath, record.Types,
			record.GenerationName, record.GenerationID, record.Height, record.Weight,
			record.Stats[0], record.Stats[1], record.Stats[2], record.Stats[3], record.Stats[4],
			record.Stats[5]); err != nil {
			return err
		}
		if err := insertLocalized(nameStatement, record.ID, record.Names); err != nil {
			return err
		}
		if err := insertLocalized(flavorStatement, record.ID, record.Flavor); err != nil {
			return err
		}
		if err := insertLocalized(genusStatement, record.ID, record.Genera); err != nil {
			return err
		}
	}

	generationStatement, err := tx.Prepare(`INSERT INTO GenerationNames (GenerationID, Language, Name) VALUES (?, ?, ?)`)
	if err != nil {
		return err
	}
	defer generationStatement.Close()

	for id, names := range generationNames {
		for lang, name := range names {
			if _, err := generationStatement.Exec(id, lang, name); err != nil {
				return err
			}
		}
	}

	return tx.Commit()
}

func insertLocalized(statement *sql.Stmt, pokemonID int, values map[string]string) error {
	for lang, value := range values {
		if _, err := statement.Exec(pokemonID, lang, value); err != nil {
			return err
		}
	}
	return nil
}
