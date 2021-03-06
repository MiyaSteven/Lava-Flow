import LavaFlow from 0x01
access(all) contract LavaToken {

  pub var totalSupply: UInt64

  pub resource interface Provider {
    pub fun withdraw(amount: UInt64): @Vault {
      post {
        result.balance == UInt64(amount):
          "Withdrawal amount must be the same as the balance of the withdrawn Vault"
      }
    }
  }

  pub resource interface Receiver {
    pub fun deposit(from: @Vault) {
      pre {
        from.balance > UInt64(0):
          "Deposit balance must be positive"
      }
    }
  }

  pub resource Vault: Provider, Receiver {
    pub var balance: UInt64

    init(balance: UInt64) {
      self.balance = balance
    }

    pub fun withdraw(amount: UInt64): @Vault {
        self.balance = self.balance - amount
        return <-create Vault(balance: amount)
    }
    
    pub fun deposit(from: @Vault) {
        self.balance = self.balance + from.balance
        destroy from
    }
  }

  pub fun createEmptyVault(): @Vault {
    return <-create Vault(balance: 0)
  }

  pub resource interface PublicLavaTokenMinter {
    pub fun convertTilePoints(tilePoints: @LavaFlow.TilePoint): @Vault
  }

  pub resource LavaTokenMinter: PublicLavaTokenMinter {
    pub fun mintTokens(amount: UInt64): @Vault {
      LavaToken.totalSupply = LavaToken.totalSupply + amount
      return <- create Vault(balance: amount)
    }

    pub fun convertTilePoints(tilePoints: @LavaFlow.TilePoint): @Vault {
      let vault <- self.mintTokens(amount: UInt64(tilePoints.amount))
      destroy tilePoints
      return <- vault
    }
  }

  init() {
    self.totalSupply = 0
    self.account.save(<-create LavaTokenMinter(), to: /storage/MainMinter)
    self.account.link<&{PublicLavaTokenMinter}>(/public/MainMinter, target: /storage/MainMinter)
  }
}
 