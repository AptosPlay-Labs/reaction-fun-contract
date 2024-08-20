#[test_only]
module chain_reaction_fun::game_room_manager_tests {
    use std::signer;
    use aptos_framework::debug;
    use aptos_framework::account;
    use aptos_framework::aptos_coin;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::timestamp;
    use chain_reaction_fun::game_room_manager::{Self};

    // Error constants
    const E_UNEXPECTED_BALANCE: u64 = 1000;
    const E_ROOM_SHOULD_BE_FULL: u64 = 1001;
    const E_ROOM_SHOULD_NOT_BE_FULL: u64 = 1002;
    const E_UNEXPECTED_REFUND: u64 = 1003;
    const E_UNEXPECTED_FEE: u64 = 1004;

    // Helper function to setup test environment
    fun setup_test(aptos_framework: &signer, chain_reaction: &signer) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        game_room_manager::initialize(chain_reaction);
    }

    // Helper function to setup player accounts
    fun setup_player_accounts(aptos_framework: &signer, player1: &signer, player2: &signer) {
        let aptos_framework_add = signer::address_of(aptos_framework);
        let player1_addr = signer::address_of(player1);
        let player2_addr = signer::address_of(player2);
        let aptos_framework = &account::create_account_for_test(aptos_framework_add);
        // let player1_sig = &account::create_account_for_test(player1_addr);
        // let player2_sig = &account::create_account_for_test(player2_addr);
        //
        // timestamp::set_time_has_started_for_testing(aptos_framework);
        // let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);
        //
        // coin::register<AptosCoin>(player1);
        // coin::register<AptosCoin>(player2);
        // let bcoin_to_mint = coin::mint(1000000, &mint_cap);


        coin::transfer<AptosCoin>(aptos_framework, player1_addr, 1000);
        coin::transfer<AptosCoin>(aptos_framework, player2_addr, 1000);
    }

    #[test(aptos_framework = @aptos_framework)]
    public fun test_initialize(aptos_framework: &signer) {
        assert!(signer::address_of(aptos_framework) == @aptos_framework, 0);
        let aptos_framework = &account::create_account_for_test(@aptos_framework);
        let chain_reaction = account::create_account_for_test(@chain_reaction_fun);

        timestamp::set_time_has_started_for_testing(aptos_framework);

        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);

        if (!coin::is_account_registered<AptosCoin>(signer::address_of(aptos_framework))) {
            coin::register<AptosCoin>(aptos_framework);
        };

        //let coins_aptos_framework = coin::mint(1000000, &mint_cap);
        //coin::deposit(signer::address_of(aptos_framework), coins_aptos_framework);
        //let balance_coin = coin::balance<AptosCoin>(signer::address_of(aptos_framework));
        //debug::print(&balance_coin);

        coin::register<AptosCoin>(&chain_reaction);
        let coins_chain_reaction = coin::mint(1000000, &mint_cap);
        coin::deposit(signer::address_of(&chain_reaction), coins_chain_reaction);
        coin::transfer<AptosCoin>(&chain_reaction, @aptos_framework, 1000);

        let balance_coin = coin::balance<AptosCoin>(signer::address_of(aptos_framework));
        debug::print(&balance_coin);

        game_room_manager::initialize(&chain_reaction);

        let room_id = game_room_manager::create_room(&chain_reaction, 100, 2);
        assert!(room_id == 1, 1);
        //print(&room_id);
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test(aptos_framework = @aptos_framework, chain_reaction = @chain_reaction_fun, player1 = @PLAYER1, player2 = @PLAYER2)]
    public fun test_create_and_join_room(
        aptos_framework: &signer,
        chain_reaction: &signer,
        player1: &signer,
        player2: &signer
    ) {
        setup_test(aptos_framework, chain_reaction);
        setup_player_accounts(aptos_framework, player1, player2);

        let room_id = game_room_manager::create_room(player1, 100, 2);
        game_room_manager::join_and_bet(player2, room_id);

        assert!(game_room_manager::is_room_full(room_id), E_ROOM_SHOULD_BE_FULL);
    }

    #[test(aptos_framework = @0x1, chain_reaction = @chain_reaction_fun, player1 = @PLAYER1, player2 = @PLAYER2)]
    #[expected_failure(abort_code = game_room_manager::E_ROOM_FULL)]
    public fun test_join_full_room(
        aptos_framework: &signer,
        chain_reaction: &signer,
        player1: &signer,
        player2: &signer
    ) {
        setup_test(aptos_framework, chain_reaction);
        setup_player_accounts(aptos_framework, player1, player2);

        let room_id = game_room_manager::create_room(player1, 100, 1);
        game_room_manager::join_and_bet(player2, room_id); // Should fail
    }

    #[test(aptos_framework = @0x1, chain_reaction = @chain_reaction_fun, player1 = @PLAYER1, player2 = @PLAYER2)]
    public fun test_leave_room(
        aptos_framework: &signer,
        chain_reaction: &signer,
        player1: &signer,
        player2: &signer
    ) {
        setup_test(aptos_framework, chain_reaction);
        setup_player_accounts(aptos_framework, player1, player2);

        let room_id = game_room_manager::create_room(player1, 100, 2);
        game_room_manager::join_and_bet(player2, room_id);

        let (success, refund) = game_room_manager::leave_room(player2, room_id);
        assert!(success, 0);
        assert!(refund == 0, E_UNEXPECTED_REFUND);

        assert!(!game_room_manager::is_room_full(room_id), E_ROOM_SHOULD_NOT_BE_FULL);
    }

    #[test(aptos_framework = @0x1, chain_reaction = @chain_reaction_fun, player1 = @PLAYER1, player2 = @PLAYER2)]
    public fun test_distribute_winnings(
        aptos_framework: &signer,
        chain_reaction: &signer,
        player1: &signer,
        player2: &signer
    ) {
        setup_test(aptos_framework, chain_reaction);
        setup_player_accounts(aptos_framework, player1, player2);

        let player1_addr = signer::address_of(player1);
        let room_id = game_room_manager::create_room(player1, 100, 2);
        game_room_manager::join_and_bet(player2, room_id);

        game_room_manager::distribute_winnings(player1_addr, 200, room_id);

        assert!(coin::balance<AptosCoin>(player1_addr) == 1100, E_UNEXPECTED_BALANCE);
    }

    #[test(aptos_framework = @0x1, chain_reaction = @chain_reaction_fun, player1 = @PLAYER1, player2 = @PLAYER2)]
    public fun test_distribute_winnings_with_fee(
        aptos_framework: &signer,
        chain_reaction: &signer,
        player1: &signer,
        player2: &signer
    ) {
        setup_test(aptos_framework, chain_reaction);
        setup_player_accounts(aptos_framework, player1, player2);

        let player1_addr = signer::address_of(player1);
        let room_id = game_room_manager::create_room(player1, 100, 2);
        game_room_manager::join_and_bet(player2, room_id);

        let fee = game_room_manager::distribute_winnings_with_fee(room_id, player1_addr, 10);

        assert!(fee == 20, E_UNEXPECTED_FEE);
        assert!(coin::balance<AptosCoin>(player1_addr) == 1180, E_UNEXPECTED_BALANCE);
        assert!(coin::balance<AptosCoin>(@chain_reaction_fun) == 20, E_UNEXPECTED_BALANCE);
    }
}