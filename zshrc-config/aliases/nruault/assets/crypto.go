package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"time"
)

var holdings = map[string]float32{
	"TRX": 171.82800000,
	"ADA": 349.23002481,
	"BTT": 22.28903200,
	"ETH": 0.00004131,
	"XLM": 330.7423416,
}

type currencies struct {
	TrxValue struct {
		Eur float32 `json:"EUR"`
	} `json:"TRX"`
	AdaValue struct {
		Eur float32 `json:"EUR"`
	} `json:"ADA"`
	BttValue struct {
		Eur float32 `json:"EUR"`
	} `json:"BTT"`
	EthValue struct {
		Eur float32 `json:"EUR"`
	} `json:"ETH"`
	XlmValue struct {
		Eur float32 `json:"EUR"`
	} `json:"XLM"`
}

func main() {

	url := "https://min-api.cryptocompare.com/data/pricemulti?fsyms=TRX,ADA,BTT,ETH,XLM&tsyms=EUR"

	spaceClient := http.Client{
		Timeout: time.Second * 5, // Maximum of 2 secs
	}

	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		log.Fatal(err)
	}

	req.Header.Set("User-Agent", "spacecount-tutorial")

	res, getErr := spaceClient.Do(req)
	if getErr != nil {
		log.Fatal(getErr)
	}

	body, readErr := ioutil.ReadAll(res.Body)
	if readErr != nil {
		log.Fatal(readErr)
	}

	var currencyHoldings currencies
	json.Unmarshal([]byte(body), &currencyHoldings)

	total :=
		currencyHoldings.TrxValue.Eur*holdings["TRX"] +
			currencyHoldings.AdaValue.Eur*holdings["ADA"] +
			currencyHoldings.BttValue.Eur*holdings["BTT"] +
			currencyHoldings.EthValue.Eur*holdings["ETH"] +
			currencyHoldings.XlmValue.Eur*holdings["XLM"]

	b, _ := json.MarshalIndent(currencyHoldings, "", "  ")
	fmt.Print(string(b))

	fmt.Print("\n", total, "€ / ~475 €")
}
