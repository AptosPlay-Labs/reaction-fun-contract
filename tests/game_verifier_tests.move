#[test_only]
module chain_reaction_fun::game_verifier_tests {
    use std::vector;
    use aptos_std::debug;
    use aptos_std::ed25519;
    use chain_reaction_fun::game_verifier;

    // Constantes para los tests
    const ROOM_ID: u64 = 1;//1234;
    const WINNER_ADDRESS: address = @PLAYER1;//@0x1;
    const GAME_STATE: vector<u8> = x"0102030405";
    //const TEST_PRIVATE_KEY: vector<u8> = x"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
    const TEST_PRIVATE_KEY: vector<u8> = x"fda68a345687e59335a67b9a330dbe205c3113a11cb1cdf689b749f7a3ab1487";
    const TEST_PUBLIC_KEY: vector<u8> = x"d0f8a1f9df5d7d1f73e3cb40d0f17da0cbaf9f09cc6c3590a0dde04e4ba11fcd";//0x2c6d33bd68066e591671c361a22cd4c02ed5c436939c163ac6c723bc3857b4b0;

    const VALID_SIGNATURE: vector<u8> = x"6bdf129a6e8c5ca856b587902af62f4f299b12647781331b0af17fed35bbbe9add5ca35e97fef6c14499223adf8a784a4b4cd543080d6778a77ca950e086fb03";//x"19dbf60154fb3d82c02ee475b7a1ce3790d8708a4af5753b649b39f1a8b1c60b4985f3dce4497f01e0691237e0a712423660494e5e635d1c43139f3cdfe4980a";
    const INVALID_SIGNATURE: vector<u8> = x"19dbf60154fb3d82c02ee475b7a1ce3790d8708a4af1234b649b39f1a8b1c60b4985f3dce4497f01e0691237e0a712423660494e5e635d1c43139f3cdfe4980a";
    const NOT_SIGNATURE: vector<u8> = x"000000000000000000000000000000000000000000000000000000";

    #[test]
    public fun text_create_mesage(){
        let message = game_verifier::room_id_to_bytes(4);
        vector::append(&mut message, game_verifier::address_to_bytes(WINNER_ADDRESS));
        vector::append(&mut message, b"0winner");
        debug::print(&message);
    }

    #[test]
    public fun test_create_signature() {
        // Crear el mensaje a firmar
        let message = game_verifier::room_id_to_bytes(ROOM_ID);
        vector::append(&mut message, game_verifier::address_to_bytes(WINNER_ADDRESS));
        vector::append(&mut message, GAME_STATE);
        debug::print(&message);

        let (sk, vpk) = ed25519::generate_keys();
        let pk = ed25519::public_key_into_unvalidated(vpk);
        //let pk_bytes = ed25519::unvalidated_public_key_to_bytes(&pk);
        debug::print(&sk);
        debug::print(&vpk);
        debug::print(&pk);

        let signature = ed25519::sign_arbitrary_bytes(&sk, message);
        debug::print(&signature);
        let signature_bytes = ed25519::signature_to_bytes(&signature);
        debug::print(&signature_bytes);
    }

    #[test]
    public fun test_create_signeture_to_win(){
        let message = game_verifier::room_id_to_bytes(ROOM_ID);
        vector::append(&mut message, game_verifier::address_to_bytes(WINNER_ADDRESS));
        vector::append(&mut message, GAME_STATE);
        debug::print(&message);
    }

    #[test]
    public fun test_verify_winner_valid_signature() {
        let result = game_verifier::verify_winner(ROOM_ID, WINNER_ADDRESS, GAME_STATE, VALID_SIGNATURE);
        assert!(result == true, 0);
    }

    #[test]
    public fun test_verify_winner_invalid_signature() {
        let result = game_verifier::verify_winner(ROOM_ID, WINNER_ADDRESS, GAME_STATE, INVALID_SIGNATURE);
        assert!(result == false, 1);
    }

    #[test]
    #[expected_failure(abort_code = 65538, location = aptos_std::ed25519)]
    public fun test_verify_winner_not_signature() {
        let result = game_verifier::verify_winner(ROOM_ID, WINNER_ADDRESS, GAME_STATE, NOT_SIGNATURE);
        assert!(result == false, 1);
    }

    #[test]
    public fun test_room_id_to_bytes() {
        let bytes = game_verifier::room_id_to_bytes(ROOM_ID);
        assert!(vector::length(&bytes) == 8, 2);
        // Aqui podrias agregar mas aserciones para verificar el contenido de los bytes
    }

    #[test]
    public fun test_address_to_bytes() {
        let bytes = game_verifier::address_to_bytes(WINNER_ADDRESS);
        assert!(vector::length(&bytes) == 32, 3); // Las direcciones en Aptos son de 32 bytes
    }

    #[test]
    public fun test_verify_winner_different_room_id() {
        let different_room_id = ROOM_ID + 1;
        let result = game_verifier::verify_winner(different_room_id, WINNER_ADDRESS, GAME_STATE, VALID_SIGNATURE);
        assert!(result == false, 4);
    }

    #[test]
    public fun test_verify_winner_different_winner() {
        let different_winner = @0x2;
        let result = game_verifier::verify_winner(ROOM_ID, different_winner, GAME_STATE, VALID_SIGNATURE);
        assert!(result == false, 5);
    }

    #[test]
    public fun test_verify_winner_different_game_state() {
        let different_game_state = x"0506070809";
        let result = game_verifier::verify_winner(ROOM_ID, WINNER_ADDRESS, different_game_state, VALID_SIGNATURE);
        assert!(result == false, 6);
    }
}