import LavaFlow from 0x01

transaction{
  prepare(acct: AuthAccount) {
  }

  execute{
    LavaFlow.startGame(gameId: UInt(1))
    log("Played Game")
  }
}
