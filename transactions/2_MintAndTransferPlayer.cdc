import LavaFlow from 0x01

// Mint and transfer players NFTs
// 
// Game instructions:
// Sign with account 0x01 to access LavaFlow's minters
// Send the transaction twice, one time for 0x03, and the second time for 0x04

transaction {
  prepare(acct: AuthAccount) {
    let receiverWallet = getAccount(0x03) // <----- Update this value to 0x03 and 0x04 
    let playeCollectionRef = receiverWallet
      .getCapability(/public/PlayersCollection)!
      .borrow<&{LavaFlow.PlayerReceiver}>()!

    let playerMinter <- acct.load<@LavaFlow.PlayerMinter>(from: /storage/PlayerMinter)!
    if playerMinter == nil {
      panic("no player minter")
    }

    let player <- playerMinter.mintPlayers(name: "Player 1", class: "Warrior")
    playeCollectionRef.deposit(token: <- player)
    acct.save<@LavaFlow.PlayerMinter>(<- playerMinter, to: /storage/PlayerMinter )
    log("Player minted and transfered")
  }
}
 