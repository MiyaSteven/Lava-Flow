import LavaFlow from 0x01

transaction {
  prepare(acct: AuthAccount) {}

  execute {
    LavaFlow.gameboardMinter.mintGameboard()
    LavaFlow.viewGames(id: UInt64(1))
  }
}
