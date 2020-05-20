import LavaFlow from 0x01

// Run the game
// 
// Game instructions:
// Any account can start a game. Update the gameId to run (line 12)

transaction {
  prepare(acct: AuthAccount) {}

  execute {
    LavaFlow.startGame(gameId: UInt(2)) // <-- Start a game by its id here
    log("Played Game")
  }
}
 