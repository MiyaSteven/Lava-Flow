import LavaFlow from 0x01

// Run the game
// 
// Game instructions:
// Any account can continue to initiate a game's next turn

transaction {
  prepare(acct: AuthAccount) {}

  execute {
    LavaFlow.nextTurn(gameId: UInt(2)) // <--- Run the next turn
    log("Played next turn Game")
  }
}
 