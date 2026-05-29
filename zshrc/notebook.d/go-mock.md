
  -----
  if err != nil {
    stats.Incr("internal.errors", stats.T("error_code", "tokenization.UpdateTokenTransaction"))
  }
  -----

  * (??) How to MOCK stats.Incr:

  `api.go`

  type statsEngine interface {
    Incr(name string, tags ...stats.Tag)
  }

  `api_test.go`

  type statsEngineMock struct{}
  func (sem *statsEngineMock) Incr(name string, tags ...stats.Tag) {}

  
