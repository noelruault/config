/*
 TRX 	171.82800000

 ADA 	99.90000000

 BTT 	22.28903200

 ETH	0.00004131
*/

// url := "https://min-api.cryptocompare.com/data/pricemulti?fsyms=TRX,ADA,BTT,ETH&tsyms=EUR"

package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"time"
)

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
}

func main() {

	url := "https://min-api.cryptocompare.com/data/pricemulti?fsyms=TRX,ADA,BTT,ETH&tsyms=EUR"

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

	mytotal := &currencies{}
	json.Unmarshal([]byte(body), &mytotal)

	total :=
		mytotal.TrxValue.Eur*171.82800000 +
			mytotal.AdaValue.Eur*99.90000000 +
			mytotal.BttValue.Eur*22.28903200 +
			mytotal.EthValue.Eur*0.00004131

	fmt.Println(total, "€")
}
