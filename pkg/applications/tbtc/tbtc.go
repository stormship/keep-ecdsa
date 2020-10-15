package tbtc

import (
	"math/big"

	"github.com/ipfs/go-log"
	"github.com/keep-network/keep-common/pkg/subscription"
	eth "github.com/keep-network/keep-ecdsa/pkg/chain"
)

var logger = log.Logger("app-tbtc")

// Handle represents a chain handle extended with TBTC-specific capabilities.
type Handle interface {
	eth.Handle

	Deposit
	TBTCSystem
}

// Deposit is an interface that provides ability to interact
// with Deposit contracts.
type Deposit interface {
}

// TBTCSystem is an interface that provides ability to interact
// with TBTCSystem contract.
type TBTCSystem interface {
	// OnDepositCreated installs a callback that is invoked when an
	// on-chain notification of a new deposit creation is seen.
	OnDepositCreated(
		handler func(depositAddress, keepAddress string, timestamp *big.Int),
	) subscription.EventSubscription
}

// InitializeActions initializes actions specific for the TBTC application.
func InitializeActions(handle Handle) {
	logger.Infof("initializing tbtc-specific actions")

	handle.OnDepositCreated(func(
		depositAddress,
		keepAddress string,
		timestamp *big.Int,
	) {
		// TODO: Implementation
	})

	logger.Infof("tbtc-specific actions have been initialized")
}
