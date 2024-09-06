module chain_reaction_fun::admin_contract {
    use std::signer;
    use std::vector;
    use std::option::{Self, Option};

    struct AdminConfig has key {
        admins: vector<address>,
        fee_account: Option<address>,
    }

    const E_NOT_ADMIN: u64 = 1;
    const E_FEE_ACCOUNT_NOT_SET: u64 = 2;
    const E_ALREADY_INITIALIZED: u64 = 3;


    fun init_module(account: &signer) {
        assert!(!exists<AdminConfig>(signer::address_of(account)), E_ALREADY_INITIALIZED);
        move_to(account, AdminConfig {
            admins: vector::singleton(signer::address_of(account)),
            fee_account: option::none(),
        });
    }

    // public fun initialize(account: &signer) {
    //     assert!(!exists<AdminConfig>(signer::address_of(account)), E_ALREADY_INITIALIZED);
    //     move_to(account, AdminConfig {
    //         admins: vector::singleton(signer::address_of(account)),
    //         fee_account: option::none(),
    //     });
    // }

    public fun is_admin(account: &signer): bool acquires AdminConfig {
        let admin_config = borrow_global<AdminConfig>(@chain_reaction_fun);
        vector::contains(&admin_config.admins, &signer::address_of(account))
    }

    public fun get_fee_account_address(): address acquires AdminConfig {
        let admin_config = borrow_global<AdminConfig>(@chain_reaction_fun);
        assert!(option::is_some(&admin_config.fee_account), E_FEE_ACCOUNT_NOT_SET);
        *option::borrow(&admin_config.fee_account)
    }

    public entry fun add_admin(admin: &signer, new_admin: address) acquires AdminConfig {
        assert!(is_admin(admin), E_NOT_ADMIN);
        let admin_config = borrow_global_mut<AdminConfig>(@chain_reaction_fun);
        if (!vector::contains(&admin_config.admins, &new_admin)) {
            vector::push_back(&mut admin_config.admins, new_admin);
        };
    }

    public entry fun remove_admin(admin: &signer, admin_to_remove: address) acquires AdminConfig {
        assert!(is_admin(admin), E_NOT_ADMIN);
        let admin_config = borrow_global_mut<AdminConfig>(@chain_reaction_fun);
        let (is_present, index) = vector::index_of(&admin_config.admins, &admin_to_remove);
        if (is_present) {
            vector::remove(&mut admin_config.admins, index);
        };
    }

    public entry fun set_fee_account(admin: &signer, fee_account: address) acquires AdminConfig {
        assert!(is_admin(admin), E_NOT_ADMIN);
        let admin_config = borrow_global_mut<AdminConfig>(@chain_reaction_fun);
        admin_config.fee_account = option::some(fee_account);
    }
}