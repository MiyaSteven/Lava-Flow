import LavaFlow from 0x01

// Add players to the game
// 
// Game instructions:
// Both 0x03 and 0x04 must individually sign this transaction to send their players into a game
// Make sure to update the owner's token id (line 24)
// Make sure to update the game id (line 29)
// Yes yes, this is not perfect 

transaction {
  let player: @LavaFlow.Player
  let playerCollectionRef: &{LavaFlow.PlayerReceiver}

  prepare(acct: AuthAccount) {
    self.playerCollectionRef = acct
      .getCapability(/public/PlayersCollection)!
      .borrow<&{LavaFlow.PlayerReceiver}>()!
    if self.playerCollectionRef == nil {
      log("Player collection ref exists")
    }
    let playerCollection <- acct.load<@LavaFlow.PlayersCollection>(from: /storage/PlayersCollection)!
    self.player <- playerCollection.withdraw(id: UInt(1)) // <-- If you minted the players for accounts 0x03 and 0x04 in asc order, 0x03 has token id 1, and 0x04 has token id 2 
    acct.save<@LavaFlow.PlayersCollection>(<- playerCollection, to: /storage/PlayersCollection)
  }

  execute {
    LavaFlow.joinGame(gameId: UInt(1), player: <- self.player, playerCollectionRef: self.playerCollectionRef) // <-- If you've created one game so far, that first game's id is 1
    log("Player added to Game")
  }
}
 