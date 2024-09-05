#[test_only]
module chain_reaction_fun::game_room_manager_tests {
    use std::signer;
    use aptos_std::debug;
    use aptos_std::account;
    use aptos_std::aptos_coin;
    use aptos_std::coin;
    use aptos_std::aptos_coin::AptosCoin;
    use aptos_std::timestamp;
    use chain_reaction_fun::admin_contract;
    use chain_reaction_fun::game_room_manager::{Self};

    // Constantes para los tests
    const ROOM_ID: u64 = 1;//1234;
    const WINNER_ADDRESS: address = @PLAYER1;//@0x1;
    const FEE_ADDRESS: address = @FEE_ADDRESS;//@0x1;
    const GAME_STATE: vector<u8> = x"0102030405";
    //const TEST_PRIVATE_KEY: vector<u8> = x"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
    const TEST_PRIVATE_KEY: vector<u8> = x"fda68a345687e59335a67b9a330dbe205c3113a11cb1cdf689b749f7a3ab1487";
    const TEST_PUBLIC_KEY: vector<u8> = x"d0f8a1f9df5d7d1f73e3cb40d0f17da0cbaf9f09cc6c3590a0dde04e4ba11fcd";//0x2c6d33bd68066e591671c361a22cd4c02ed5c436939c163ac6c723bc3857b4b0;

    const VALID_SIGNATURE: vector<u8> = x"6bdf129a6e8c5ca856b587902af62f4f299b12647781331b0af17fed35bbbe9add5ca35e97fef6c14499223adf8a784a4b4cd543080d6778a77ca950e086fb03";//x"19dbf60154fb3d82c02ee475b7a1ce3790d8708a4af5753b649b39f1a8b1c60b4985f3dce4497f01e0691237e0a712423660494e5e635d1c43139f3cdfe4980a";
    const INVALID_SIGNATURE: vector<u8> = x"19dbf60154fb3d82c02ee475b7a1ce3790d8708a4af1234b649b39f1a8b1c60b4985f3dce4497f01e0691237e0a712423660494e5e635d1c43139f3cdfe4980a";
    const NOT_SIGNATURE: vector<u8> = x"000000000000000000000000000000000000000000000000000000";

    // Error constants
    const E_UNEXPECTED_BALANCE: u64 = 1000;
    const E_ROOM_SHOULD_BE_FULL: u64 = 1001;
    const E_ROOM_SHOULD_NOT_BE_FULL: u64 = 1002;
    const E_UNEXPECTED_REFUND: u64 = 1003;
    const E_UNEXPECTED_FEE: u64 = 1004;

    // Helper function to setup player accounts
    fun setup_player_accounts(aptos_framework: &signer, chain_reaction: &signer, player1: &signer, player2: &signer, fee_address : &signer) {
        assert!(signer::address_of(aptos_framework) == @aptos_framework, 0);
        let chain_reaction_addr = signer::address_of(chain_reaction);
        let aptos_framework_addr = signer::address_of(aptos_framework);
        let player1_addr = signer::address_of(player1);
        let player2_addr = signer::address_of(player2);
        let fee_addr = signer::address_of(fee_address);

        let aptos_framework = &account::create_account_for_test(aptos_framework_addr);

        timestamp::set_time_has_started_for_testing(aptos_framework);
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);

        coin::register<AptosCoin>(aptos_framework);

        let coin_to_mint = coin::mint(1000000, &mint_cap);
        coin::deposit(signer::address_of(aptos_framework), coin_to_mint);

        account::create_account_for_test(player1_addr);
        account::create_account_for_test(player2_addr);
        account::create_account_for_test(fee_addr);
        account::create_account_for_test(chain_reaction_addr);

        coin::register<AptosCoin>(player1);
        coin::register<AptosCoin>(player2);
        coin::register<AptosCoin>(fee_address);
        coin::register<AptosCoin>(chain_reaction);

        coin::transfer<AptosCoin>(aptos_framework, chain_reaction_addr, 1000);
        coin::transfer<AptosCoin>(aptos_framework, player1_addr, 1000);
        coin::transfer<AptosCoin>(aptos_framework, player2_addr, 1000);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
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

    #[test(aptos_framework = @aptos_framework, chain_reaction = @chain_reaction_fun, player1 = @PLAYER1, player2 = @PLAYER2, fee_address = @FEE_ADDRESS)]
    public fun test_create_and_join_room(
        aptos_framework: &signer,
        chain_reaction: &signer,
        player1: &signer,
        player2: &signer,
        fee_address: &signer
    ) {
        setup_player_accounts(aptos_framework, chain_reaction, player1, player2, fee_address);

        game_room_manager::initialize(chain_reaction);
        let room_id = game_room_manager::create_room(chain_reaction, 100, 2);
        assert!(room_id == 1, 1);

        game_room_manager::join_and_bet(player2, room_id);

        assert!(game_room_manager::is_room_full(room_id), E_ROOM_SHOULD_BE_FULL);
    }

    #[test(aptos_framework = @aptos_framework, chain_reaction = @chain_reaction_fun, player1 = @PLAYER1, player2 = @PLAYER2, fee_address = @FEE_ADDRESS)]
    #[expected_failure(abort_code = game_room_manager::E_ROOM_MIN_PLAYERS)]
    public fun test_create_room_min_player( aptos_framework: &signer, chain_reaction: &signer, player1: &signer, player2: &signer, fee_address: &signer) {

        setup_player_accounts(aptos_framework, chain_reaction, player1, player2, fee_address);
        game_room_manager::initialize(chain_reaction);

        game_room_manager::create_room(chain_reaction, 100, 1);
    }

    #[test(aptos_framework = @aptos_framework, chain_reaction = @chain_reaction_fun, player1 = @PLAYER1, player2 = @PLAYER2, fee_address = @FEE_ADDRESS)]
    #[expected_failure(abort_code = game_room_manager::E_ROOM_FULL)]
    public fun test_join_full_room( aptos_framework: &signer, chain_reaction: &signer, player1: &signer, player2: &signer, fee_address: &signer) {

        setup_player_accounts(aptos_framework, chain_reaction, player1, player2, fee_address);
        game_room_manager::initialize(chain_reaction);

        let room_id = game_room_manager::create_room(chain_reaction, 100, 2);
        game_room_manager::join_and_bet(player1, room_id);
        game_room_manager::join_and_bet(player2, room_id);
    }


    #[test(aptos_framework = @aptos_framework, chain_reaction = @chain_reaction_fun, player1 = @PLAYER1, player2 = @PLAYER2, fee_address = @FEE_ADDRESS)]
    public fun test_leave_room( aptos_framework: &signer, chain_reaction: &signer, player1: &signer, player2: &signer, fee_address: &signer) {

        setup_player_accounts(aptos_framework, chain_reaction, player1, player2, fee_address);
        game_room_manager::initialize(chain_reaction);

        let room_id = game_room_manager::create_room(player1, 100, 3);
        game_room_manager::join_and_bet(player2, room_id);

        let balance_coin = coin::balance<AptosCoin>(signer::address_of(player2));
        debug::print(&balance_coin);

        let (success, refund) = game_room_manager::leave_room(player2, room_id);

        let balance_coin = coin::balance<AptosCoin>(signer::address_of(player2));
        debug::print(&balance_coin);

        assert!(success, 0);
        assert!(refund == 0, E_UNEXPECTED_REFUND);

        assert!(!game_room_manager::is_room_full(room_id), E_ROOM_SHOULD_NOT_BE_FULL);
    }

    //Mejorar test para que se sin fee
    // #[test(aptos_framework = @aptos_framework, chain_reaction = @chain_reaction_fun, player1 = @PLAYER1, player2 = @PLAYER2)]
    // public fun test_distribute_winnings( aptos_framework: &signer, chain_reaction: &signer, player1: &signer, player2: &signer) {
    //
    //     setup_player_accounts(aptos_framework, chain_reaction, player1, player2);
    //     game_room_manager::initialize(chain_reaction);
    //
    //     let player1_addr = signer::address_of(player1);
    //     let room_id = game_room_manager::create_room(player1, 100, 2);
    //     game_room_manager::join_and_bet(player2, room_id);
    //
    //     game_room_manager::distribute_winnings(player1_addr, 200, room_id);
    //
    //     assert!(coin::balance<AptosCoin>(player1_addr) == 1100, E_UNEXPECTED_BALANCE);
    // }

    #[test(aptos_framework = @aptos_framework, chain_reaction = @chain_reaction_fun, player1 = @PLAYER1, player2 = @PLAYER2, fee_address = @FEE_ADDRESS)]
    public fun test_distribute_winnings_with_fee( aptos_framework: &signer, chain_reaction: &signer, player1: &signer, player2: &signer, fee_address: &signer) {

        setup_player_accounts(aptos_framework, chain_reaction, player1, player2, fee_address);
        game_room_manager::initialize(chain_reaction);
        admin_contract::initialize(chain_reaction);
        admin_contract::set_fee_account(chain_reaction, FEE_ADDRESS);

        let player1_addr = signer::address_of(player1);
        let room_id = game_room_manager::create_room(player1, 100, 2);
        game_room_manager::join_and_bet(player2, room_id);

        let fee = game_room_manager::declare_winner_distribute_winnings(player1, room_id, player1_addr, GAME_STATE, VALID_SIGNATURE, 10);

        assert!(fee == 20, E_UNEXPECTED_FEE);
        assert!(coin::balance<AptosCoin>(player1_addr) == 1080, E_UNEXPECTED_BALANCE);
        assert!(coin::balance<AptosCoin>(@chain_reaction_fun) == 1000, E_UNEXPECTED_BALANCE);
        assert!(coin::balance<AptosCoin>(signer::address_of(fee_address)) == 20, E_UNEXPECTED_BALANCE);
    }

}