module chain_reaction_fun::admin_contract {
    use std::signer;
    use std::vector;

    struct AdminConfig has key {
        admins: vector<address>,
    }

    const E_NOT_ADMIN: u64 = 1;

    public fun initialize(account: &signer) {
        move_to(account, AdminConfig {
            admins: vector::singleton(signer::address_of(account)),
        });
    }

    public fun is_admin(account: &signer): bool acquires AdminConfig {
        let admin_config = borrow_global<AdminConfig>(@chain_reaction);
        vector::contains(&admin_config.admins, &signer::address_of(account))
    }

    public entry fun add_admin(admin: &signer, new_admin: address) acquires AdminConfig {
        assert!(is_admin(admin), E_NOT_ADMIN);
        let admin_config = borrow_global_mut<AdminConfig>(@chain_reaction);
        if (!vector::contains(&admin_config.admins, &new_admin)) {
            vector::push_back(&mut admin_config.admins, new_admin);
        };
    }

    public entry fun remove_admin(admin: &signer, admin_to_remove: address) acquires AdminConfig {
        assert!(is_admin(admin), E_NOT_ADMIN);
        let admin_config = borrow_global_mut<AdminConfig>(@chain_reaction);
        let (is_present, index) = vector::index_of(&admin_config.admins, &admin_to_remove);
        if (is_present) {
            vector::remove(&mut admin_config.admins, index);
        };
    }
}
