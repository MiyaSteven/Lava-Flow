import LavaFlow from 0x01
// Add a player to the game
// Note: Both 0x02 and 0x03 have to send this transaction
// Update the player token id (line 17) and the gameId (line 22)
transaction{

  let player: @LavaFlow.Player
  let playerCollectionRef: &{LavaFlow.PlayerReceiver}
  prepare(acct: AuthAccount) {
    self.playerCollectionRef = acct
      .getCapability(/public/PlayersCollection)!
      .borrow<&{LavaFlow.PlayerReceiver}>()!
    if(self.playerCollectionRef == nil){
      log("Player collection ref exists")
    }
    let playerCollection <- acct.load<@LavaFlow.PlayersCollection>(from: /storage/PlayersCollection)!
    self.player <- playerCollection.withdraw(id: UInt(2))
    acct.save<@LavaFlow.PlayersCollection>(<- playerCollection, to: /storage/PlayersCollection)
  }

  execute{
    LavaFlow.joinGame(gameId: UInt(1), player: <- self.player, playerCollectionRef: self.playerCollectionRef)
    log("Player added to Game")
  }
}
 