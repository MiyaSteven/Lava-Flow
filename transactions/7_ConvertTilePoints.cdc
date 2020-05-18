import LavaFlow from 0x01
import LavaToken from 0x02

transaction {

  let minterRef: &{LavaToken.PublicLavaTokenMinter}
  
  let vaultReference: &{LavaToken.Receiver}
  prepare(acct: AuthAccount) {
    let lavaTokenAccount = getAccount(0x02)
    self.minterRef = lavaTokenAccount.getCapability(/public/MainMinter)!
      .borrow<&{LavaToken.PublicLavaTokenMinter}>()!
    let playerCollection = acct.borrow<&LavaFlow.PlayersCollection>(from: /storage/PlayersCollection)!
    self.vaultReference = acct
      .getCapability(/public/LavaTokenVault)!
      .borrow<&{LavaToken.Receiver}>()!
    let player <- playerCollection.withdraw(id: UInt(2))
    var i = player.tilePoints.length
    while i > 0 {
      let tilePoints <- player.removeTilePoints(position: UInt(0))
      log("TilePoints amount")
      log(tilePoints.amount)
      let vault <- self.minterRef.convertTilePoints(tilePoints:<- tilePoints)
      self.vaultReference.deposit(from: <- vault)
      i = i - 1
    }
    playerCollection.deposit(token: <-player )
    log("Transfered tokens")
    // get the player
    // get the tile points
    // put back the player
    // get the vaultReceiver
    // mint tokens
    // transfer to vault
  }
  execute{
  }
}
 