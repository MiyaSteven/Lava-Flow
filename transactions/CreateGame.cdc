import LavaFlow from 0x01

transaction{

  prepare(acct: AuthAccount) {
  }

  execute{
    LavaFlow.createGame(totalPlayerCount: UInt(2))
    log("Game created")
  }
}
 