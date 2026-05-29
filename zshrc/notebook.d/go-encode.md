

  // Here&#39;s the string we&#39;ll encode/decode.
  data := &#34;abc123!?$*&amp;()&#39;-=@~&#34;

  // Go supports both standard and URL-compatible base64.
  // Here&#39;s how to encode using the standard encoder.
  // The encoder requires a []byte so we convert our string to that type.
  sEnc := b64.StdEncoding.EncodeToString([]byte(data))
  fmt.Println(sEnc)

  // Decoding may return an error, which you can check
  // if you don&#39;t already know the input to be well-formed.
  sDec, _ := b64.StdEncoding.DecodeString(sEnc)
  fmt.Println(string(sDec))
  fmt.Println()

  // This encodes/decodes using a URL-compatible base64 format.
  uEnc := b64.URLEncoding.EncodeToString([]byte(data))
  fmt.Println(uEnc)
  uDec, _ := b64.URLEncoding.DecodeString(uEnc)
  fmt.Println(string(uDec))

  // TIP: Sometimes is safer to encode an already read file

  jsonKeyFile, err := ioutil.ReadFile(fmt.Sprintf('.keys/production-credentials-file.json'))
  if err != nil {
    log.Fatal(err)
  }
  encKey := base64.URLEncoding.EncodeToString(jsonKeyFile)
  fmt.Println(encKey) // Getting the encode of an already read file. Nothing can go wrong.

  [Reference]: https://play.golang.org/p/S7ff3UgzNlG
  
