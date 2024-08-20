module chain_reaction_fun::game_verifier {

    use std::bcs;
    use std::vector;
    use aptos_std::ed25519;

    const SERVER_PUBLIC_KEY: vector<u8> = x"8a66ebbc8cd1bd6424c8a9fc1e8d7333e9cd5ebfaad6e1e9d178406c383d7ba3";// Replace with actual public key

    public fun verify_winner(room_id: u64, winner_address: address, game_state: vector<u8>, signature: vector<u8>): bool {
        let message = room_id_to_bytes(room_id);
        vector::append(&mut message, address_to_bytes(winner_address));
        vector::append(&mut message, game_state);

        let signature = ed25519::new_signature_from_bytes(signature);
        let public_key = ed25519::new_unvalidated_public_key_from_bytes(SERVER_PUBLIC_KEY);
        ed25519::signature_verify_strict(&signature, &public_key, message)
    }

    fun room_id_to_bytes(room_id: u64): vector<u8> {
        let bytes = vector::empty<u8>();
        let i = 0;
        while (i < 8) {
            vector::push_back(&mut bytes, ((room_id >> ((7 - i) * 8)) & 0xFF as u8));
            i = i + 1;
        };
        bytes
    }

    fun address_to_bytes(addr: address): vector<u8> {
        bcs::to_bytes(&addr)
    }

}
