package ethereum

import (
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	relaychain "github.com/keep-network/keep-core/pkg/beacon/relay/chain"
	"github.com/keep-network/keep-core/pkg/chain"
)

type ethereumStakeMonitor struct {
	ethereum *Chain
}

func (esm *ethereumStakeMonitor) HasMinimumStake(address string) (bool, error) {
	if !common.IsHexAddress(address) {
		return false, fmt.Errorf("not a valid ethereum address: %v", address)
	}

	return esm.ethereum.HasMinimumStake(common.HexToAddress(address))
}

func (esm *ethereumStakeMonitor) StakerFor(address string) (chain.Staker, error) {
	if !common.IsHexAddress(address) {
		return nil, fmt.Errorf("not a valid ethereum address: %v", address)
	}

	return &ethereumStaker{
		address:  address,
		ethereum: esm.ethereum,
	}, nil
}

// StakeMonitor generates a new `chain.StakeMonitor` from the chain
func (ec *Chain) StakeMonitor() (chain.StakeMonitor, error) {
	return &ethereumStakeMonitor{ec}, nil
}

type ethereumStaker struct {
	address  string
	ethereum *Chain
}

func (es *ethereumStaker) Address() relaychain.StakerAddress {
	return common.HexToAddress(es.address).Bytes()
}

func (es *ethereumStaker) Stake() (*big.Int, error) {
	return es.ethereum.BalanceOf(common.HexToAddress(es.address))
}
