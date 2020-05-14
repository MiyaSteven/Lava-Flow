import LavaFlow from 0x01
// Run the game
// Anyone can run a game. Update the gameId to run (line 9)
transaction{
  prepare(acct: AuthAccount) {
  }

  execute{
    LavaFlow.startGame(gameId: UInt(1))
    log("Played Game")
  }
}
