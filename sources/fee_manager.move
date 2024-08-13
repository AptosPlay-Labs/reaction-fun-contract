module chain_reaction_fun::fee_manager {
    use std::signer;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::event;
    
    struct FeeAccount has key {
        balance: u64,
    }

    #[event]
    struct FeeAdded has drop, store {
        amount: u64,
        new_balance: u64,
    }

    #[event]
    struct FeeWithdrawn has drop, store {
        amount: u64,
        recipient: address,
    }

    const ENOT_ADMIN: u64 = 1;
    const EINSUFFICIENT_BALANCE: u64 = 2;

    public fun initialize(account: &signer) {
        let sender = signer::address_of(account);
        assert!(sender == @admin_address, ENOT_ADMIN);

        move_to(account, FeeAccount { balance: 0 });
    }

    public fun add_fee(amount: u64) acquires FeeAccount {
        let fee_account = borrow_global_mut<FeeAccount>(@admin_address);
        fee_account.balance = fee_account.balance + amount;

        event::emit(FeeAdded {
            amount,
            new_balance: fee_account.balance,
        });
    }

    public fun withdraw_fees(account: &signer, amount: u64) acquires FeeAccount {
        let sender = signer::address_of(account);
        assert!(sender == @admin_address, ENOT_ADMIN);

        let fee_account = borrow_global_mut<FeeAccount>(@admin_address);
        assert!(fee_account.balance >= amount, EINSUFFICIENT_BALANCE);

        fee_account.balance = fee_account.balance - amount;

        coin::transfer<AptosCoin>(@admin_address, sender, amount);

        event::emit(FeeWithdrawn {
            amount,
            recipient: sender,
        });
    }

    #[view]
    public fun get_fee_balance(): u64 acquires FeeAccount {
        borrow_global<FeeAccount>(@admin_address).balance
    }

    #[test(admin = @admin_address)]
    public entry fun test_fee_management(admin: signer) acquires FeeAccount {
        initialize(&admin);
        
        assert!(get_fee_balance() == 0, 0);

        add_fee(100);
        assert!(get_fee_balance() == 100, 1);

        add_fee(50);
        assert!(get_fee_balance() == 150, 2);

        withdraw_fees(&admin, 75);
        assert!(get_fee_balance() == 75, 3);
    }
}