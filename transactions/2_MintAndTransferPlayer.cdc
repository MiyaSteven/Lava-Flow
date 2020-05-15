import LavaFlow from 0x01
// Mint and transfer players token
// Note: Use account 0x01 since he's the one controlling the minter
// Send the transaction twice, One for 0x02 and the other for 0x03
transaction{

  prepare(acct: AuthAccount) {
    let receiverWallet = getAccount(0x03)
    let playeCollectionRef = receiverWallet
      .getCapability(/public/PlayersCollection)!
      .borrow<&{LavaFlow.PlayerReceiver}>()!
    let playerMinter <- acct.load<@LavaFlow.PlayerMinter>(from: /storage/PlayerMinter)!
    if(playerMinter == nil){
      panic("no player minter")
    }
    let player <- playerMinter.mintPlayers(name: "Player 1", class: "Warrior")
    playeCollectionRef.deposit(token: <- player)
    acct.save<@LavaFlow.PlayerMinter>(<- playerMinter, to: /storage/PlayerMinter )
    log("Player minted and transfered")
  }
  
}
 