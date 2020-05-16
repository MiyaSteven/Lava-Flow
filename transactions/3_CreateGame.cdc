import LavaFlow from 0x01
// Create a new game
// Note: any account can create a game
transaction {
  prepare(acct: AuthAccount) {}
  execute {
    LavaFlow.createGame(totalPlayerCount: UInt(2))
    log("Game created")
  }
}
 