use blobert::TokenAttributes;
use starknet::ContractAddress;

#[starknet::interface]
trait IArenaBlobert<TContractState> {
    fn burn(ref self: TContractState, token_id: u256);
    fn traits(self: @TContractState, token_id: u256) -> TokenAttributes;
}

#[starknet::interface]
trait IArenaBlobertAdmin<TContractState> {
    fn mint(ref self: TContractState, owner: ContractAddress, attributes: TokenAttributes) -> u256;
}


const ARENA_BLOBERT_NAMESPACE_HASH: felt252 = bytearray_hash!("arena_blobert");

#[starknet::contract]
mod arena_blobert_actions {
    use blobert::{Seed, TokenAttributes};
    use dojo_beacon::dojo::const_ns;
    use dojo_beacon::dojo::traits::BeaconEmitterTrait;
    use dojo_beacon::emitter_component;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc721::{ERC721Component, ERC721HooksEmptyImpl, interface};
    use openzeppelin_upgrades::UpgradeableComponent;
    use openzeppelin_upgrades::interface::IUpgradeable;
    use sai_access::{AccessTrait, access_component};
    use sai_token::erc721::{ERC721MetadataInfo, soulbound};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ClassHash, ContractAddress, get_caller_address};
    use super::{ARENA_BLOBERT_NAMESPACE_HASH, IArenaBlobert, IArenaBlobertAdmin};

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: emitter_component, storage: emitter, event: EmitterEvents);
    component!(path: access_component, storage: access, event: AccessEvents);

    #[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
    enum TokenType {
        #[default]
        NotMinted,
        Seed,
        Custom,
    }

    #[dojo::model]
    #[derive(Copy, Drop, Serde, PartialEq)]
    struct ArenaBlobertToken {
        #[key]
        token_id: u256,
        attributes: TokenAttributes,
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        emitter: emitter_component::Storage,
        #[substorage(v0)]
        access: access_component::Storage,
        tokens_minted: u128,
        token_seeds: Map<u256, Seed>,
        token_customs: Map<u256, felt252>,
        token_types: Map<u256, TokenType>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        EmitterEvents: emitter_component::Event,
        #[flat]
        AccessEvents: access_component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.erc721.initializer_no_metadata();
        self.grant_owner(owner);
        self.src5.register_interface(interface::IERC721_METADATA_ID);
    }

    #[abi(embed_v0)]
    impl ERC721Impl =
        soulbound::ERC721Soulbound<ContractState, ERC721MetadataInfoImpl>;

    #[abi(embed_v0)]
    impl AccessImpl = access_component::AccessImpl<ContractState>;

    #[abi(embed_v0)]
    impl IArenaBlobertImpl of IArenaBlobert<ContractState> {
        fn burn(ref self: ContractState, token_id: u256) {
            self.caller_is_token_owner(token_id);
            self.erc721.burn(token_id);
        }

        fn traits(self: @ContractState, token_id: u256) -> TokenAttributes {
            let token_type = self.token_types.read(token_id);
            match token_type {
                TokenType::Seed => { TokenAttributes::Seed(self.token_seeds.read(token_id)) },
                TokenType::Custom => { TokenAttributes::Custom(self.token_customs.read(token_id)) },
                _ => panic!("Token not minted"),
            }
        }
    }

    #[abi(embed_v0)]
    impl IArenaBlobertAdminImpl of IArenaBlobertAdmin<ContractState> {
        fn mint(
            ref self: ContractState, owner: ContractAddress, attributes: TokenAttributes,
        ) -> u256 {
            self.assert_caller_is_writer();
            self.mint_internal(owner, attributes)
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.assert_caller_is_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    // Internal
    impl ERC721MetadataInfoImpl of ERC721MetadataInfo {
        fn name() -> ByteArray {
            "Arena Blobert"
        }

        fn symbol() -> ByteArray {
            "BABLOB"
        }

        fn base_token_uri() -> ByteArray {
            "http://www.example.com/"
        }
    }

    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;

    impl Emitter = const_ns::ConstNsBeaconEmitter<ARENA_BLOBERT_NAMESPACE_HASH, ContractState>;

    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn mint_internal(
            ref self: ContractState, owner: ContractAddress, attributes: TokenAttributes,
        ) -> u256 {
            let minted = self.tokens_minted.read() + 1;
            self.tokens_minted.write(minted);
            let token_id: u256 = minted.into() + 4844;
            match attributes {
                TokenAttributes::Seed(seed) => {
                    self.token_seeds.write(token_id, seed);
                    self.token_types.write(token_id, TokenType::Seed);
                },
                TokenAttributes::Custom(custom) => {
                    self.token_customs.write(token_id, custom);
                    self.token_types.write(token_id, TokenType::Custom);
                },
            }
            self.emit_model(@ArenaBlobertToken { token_id, attributes });
            self.erc721.mint(owner, token_id);

            token_id
        }

        fn caller_is_token_owner(self: @ContractState, token_id: u256) {
            assert(
                get_caller_address() == self.erc721._owner_of(token_id),
                'Caller is not the token owner',
            );
        }
    }
}

