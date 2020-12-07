import { callWithRetry } from "./contract-helper.js"

export default class Conditions {
  constructor(
    context,
    interval,
    bondedECDSAKeepFactory,
    keepBonding,
    sortitionPoolAddress
  ) {
    this.context = context
    this.interval = interval
    this.bondedECDSAKeepFactory = bondedECDSAKeepFactory
    this.keepBonding = keepBonding
    this.sortitionPoolAddress = sortitionPoolAddress
    this.operatorsDeauthorizedInInterval = []
  }

  static async initialize(context, interval) {
    const { contracts } = context

    const bondedECDSAKeepFactory = await contracts.BondedECDSAKeepFactory.deployed()

    const sortitionPoolAddress = await callWithRetry(
      bondedECDSAKeepFactory.methods.getSortitionPool(
        contracts.sanctionedApplicationAddress
      )
    )

    const conditions = new Conditions(
      context,
      interval,
      bondedECDSAKeepFactory,
      await contracts.KeepBonding.deployed(),
      sortitionPoolAddress
    )

    return conditions
  }

  async checkDeauthorizations() {
    // If Tenderly API is available refresh cached data.
    if (this.context.tenderly) {
      this.refreshDeauthorizationsCache()
    }

    // Fetch deauthorization transactions from cache.
    // We expect only successful transactions to be returned, which means we don't
    // need to double check authorizer vs operator as this was already handled
    // by the contract on the function call.
    const deauthorizations = this.context.cache.getTransactionFunctionCalls(
      this.keepBonding.options.address,
      "deauthorizeSortitionPoolContract"
    )

    console.debug(
      `Found ${deauthorizations.length} sortition pool contract deauthorizations`
    )

    if (deauthorizations && deauthorizations.length > 0) {
      for (let i = 0; i < deauthorizations.length; i++) {
        const transaction = deauthorizations[i]

        console.debug(`Checking transaction ${transaction.hash}`)

        if (
          transaction.block_number < this.interval.startBlock ||
          transaction.block_number > this.interval.endBlock
        ) {
          console.debug(
            `Skipping transaction made in block ${transaction.block_number}`
          )
          continue
        }

        const operator = transaction.decoded_input[0].value
        const inputSortitionPool = transaction.decoded_input[1].value

        if (
          inputSortitionPool.toLowerCase() !=
          this.sortitionPoolAddress.toLowerCase()
        ) {
          console.debug(
            `Skipping transaction for sortition pool ${inputSortitionPool}`
          )
          continue
        }

        this.operatorsDeauthorizedInInterval.push(operator.toLowerCase())
      }
    }

    if (this.operatorsDeauthorizedInInterval.length > 0) {
      console.log(
        `Discovered deauthorizations in the current interval for operators [${this.operatorsDeauthorizedInInterval}]`
      )
    }
  }

  async refreshDeauthorizationsCache() {
    console.log("Refreshing cached sortition pool deauthorization transactions")

    const data = await this.context.tenderly.getFunctionCalls(
      this.keepBonding.options.address,
      "deauthorizeSortitionPoolContract(address,address)"
    )

    const transactions = data
      .filter((tx) => tx.status === true) // filter only successful transactions
      .map((tx) => {
        return {
          hash: tx.hash,
          from: tx.from,
          to: tx.to,
          block_number: tx.block_number,
          method: tx.method,
          decoded_input: tx.decoded_input,
        }
      })

    this.context.cache.storeTransactions(transactions)
  }

  async checkAuthorizations(operator) {
    console.debug(`Checking authorizations for operator ${operator}`)

    // Authorizations at the interval start.
    const {
      wasFactoryAuthorized: factoryAuthorizedAtStart,
      wasSortitionPoolAuthorized: poolAuthorizedAtStart,
    } = await this.checkAuthorizationsAtIntervalStart(operator)

    // Deauthorizations during the interval.
    const poolDeauthorizedInInterval = await this.wasSortitionPoolDeauthorized(
      operator
    )

    return new OperatorAuthorizations(
      operator,
      factoryAuthorizedAtStart,
      poolAuthorizedAtStart,
      poolDeauthorizedInInterval
    )
  }

  async checkAuthorizationsAtIntervalStart(operator) {
    // Operator contract
    const wasFactoryAuthorized = await callWithRetry(
      this.bondedECDSAKeepFactory.methods.isOperatorAuthorized(operator),
      this.interval.startBlock
    )

    // Sortition pool
    const wasSortitionPoolAuthorized = await callWithRetry(
      this.keepBonding.methods.hasSecondaryAuthorization(
        operator,
        this.sortitionPoolAddress
      ),
      this.interval.startBlock
    )

    return { wasFactoryAuthorized, wasSortitionPoolAuthorized }
  }

  async wasSortitionPoolDeauthorized(operator) {
    return this.operatorsDeauthorizedInInterval.includes(operator.toLowerCase())
  }
}

export function OperatorAuthorizations(
  address,
  factoryAuthorizedAtStart,
  poolAuthorizedAtStart,
  poolDeauthorizedInInterval
) {
  ;(this.address = address),
    (this.factoryAuthorizedAtStart = factoryAuthorizedAtStart),
    (this.poolAuthorizedAtStart = poolAuthorizedAtStart),
    (this.poolDeauthorizedInInterval = poolDeauthorizedInInterval)
}
