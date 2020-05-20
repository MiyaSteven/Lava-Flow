import LavaFlow from 0x01
// Create a new game
// 
// Game instructions:
// Any account can sign this contract to create a game. 

transaction {
  prepare(acct: AuthAccount) {}
  execute {
    LavaFlow.createGame(totalPlayerCount: UInt(2)) // <--- Change this value to indicate the number of players. 2 is enough
    log("Game created")
  }
}
 