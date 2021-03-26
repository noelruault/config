package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"strings"
	"time"
)

const (
	spendTotal    = 975 // approximate expenses on cryptos so far
	spendCurrency = "EUR"
)

var (
	holdings = map[string]float32{
		"ADA": 349.23002481, // ~350
		"BTT": 22.28903200,
		"ETH": 0.00004131,
		"TRX": 180.44750201,
		"VET": 6292,        // 393
		"XLM": 330.7423416, // 134.72
		"ZIL": 706.8,       // 100
	}
	currencyIcon = map[string]string{
		"EUR": "€",
		"USD": "US$",
	}
)

func main() {
	var cryptoAliases []string
	for i := range holdings {
		cryptoAliases = append(cryptoAliases, i)
	}

	url := fmt.Sprintf(
		"https://min-api.cryptocompare.com/data/pricemulti?fsyms=%s&tsyms=%s",
		strings.Join(cryptoAliases, ","),
		spendCurrency,
	)
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		log.Fatal(err)
	}

	httpClient := http.Client{Timeout: time.Second * 5}
	res, getErr := httpClient.Do(req)
	if getErr != nil {
		log.Fatal(getErr)
	}

	body, readErr := ioutil.ReadAll(res.Body)
	if readErr != nil {
		log.Fatal(readErr)
	}

	var cryptoCurrentValues map[string]map[string]float32
	json.Unmarshal([]byte(body), &cryptoCurrentValues)

	var holdingValues float32
	for i := range holdings {
		if cryptoCurrentValues[i][spendCurrency] == 0 {
			log.Fatalf("%s: crypto not added yet or not handled correctly", i)
		}
		holdingValues += cryptoCurrentValues[i][spendCurrency] * holdings[i]
	}

	fmt.Printf("\n%f%s / ~%d%s", holdingValues, currencyIcon[spendCurrency], spendTotal, currencyIcon[spendCurrency])
}
