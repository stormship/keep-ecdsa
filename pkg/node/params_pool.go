package node

import (
	"sync"

	"github.com/binance-chain/tss-lib/ecdsa/keygen"
	"github.com/keep-network/keep-tecdsa/pkg/ecdsa/tss"
)

// TSSPreParamsPool is a pool holding TSS pre parameters. It autogenerates entries
// up to the pool size. When an entry is pulled from the pool it will generate
// new entry.
type TSSPreParamsPool struct {
	pumpFuncMutex *sync.Mutex // lock concurrent executions of pumping function

	paramsMutex *sync.Cond
	params      []*keygen.LocalPreParams

	new func() (*keygen.LocalPreParams, error)

	poolSize int
}

// InitializeTSSPreParamsPool generates TSS pre-parameters and stores them in a pool.
func (t *Node) InitializeTSSPreParamsPool() {
	t.tssParamsPool = &TSSPreParamsPool{
		pumpFuncMutex: &sync.Mutex{},
		paramsMutex:   sync.NewCond(&sync.Mutex{}),
		params:        []*keygen.LocalPreParams{},
		poolSize:      2,
		new: func() (*keygen.LocalPreParams, error) {
			return tss.GenerateTSSPreParams()
		},
	}

	go t.tssParamsPool.pumpPool()
}

func (t *TSSPreParamsPool) pumpPool() {
	t.pumpFuncMutex.Lock()
	defer t.pumpFuncMutex.Unlock()

	for {
		if len(t.params) >= t.poolSize {
			logger.Debugf("tss pre parameters pool is pumped")
			return
		}

		params, err := t.new()
		if err != nil {
			logger.Warningf("failed to generate tss pre parameters: [%v]", err)
			return
		}

		t.paramsMutex.L.Lock()
		t.params = append(t.params, params)
		t.paramsMutex.Signal()
		t.paramsMutex.L.Unlock()

		logger.Debugf("generated new tss pre parameters")
	}
}

// Get returns TSS pre parameters from the pool. It pumps the pool after getting
// and entry. If the pool is empty it will wait for a new entry to be generated.
func (t *TSSPreParamsPool) Get() *keygen.LocalPreParams {
	t.paramsMutex.L.Lock()
	defer t.paramsMutex.L.Unlock()

	for len(t.params) == 0 {
		t.paramsMutex.Wait()
	}

	params := t.params[0]
	t.params = t.params[1:len(t.params)]

	go t.pumpPool()

	return params
}
