use starknet::ContractAddress;
use starknet::class_hash::ClassHash;

#[derive(Drop, Serde, starknet::Store, Clone)]
pub struct FundOwnerInfo {
    fund_index: u128,
    fund_address: ContractAddress,
    owner: ContractAddress
}

#[starknet::interface]
pub trait IFundManager<TContractState> {
    fn new_fund(
        ref self: TContractState,
        name: ByteArray,
        goal: u256,
        evidence_link: ByteArray,
        contact_handle: ByteArray,
        reason: ByteArray,
        fund_type: u8,
    );
    fn get_current_id(self: @TContractState) -> u128;
    fn get_fund(self: @TContractState, id: u128) -> ContractAddress;
    fn get_owner(self: @TContractState) -> ContractAddress;
    fn get_fund_class_hash(self: @TContractState) -> ClassHash;
    fn get_all_fund_owners(self: @TContractState) -> Array<FundOwnerInfo>;
}

#[starknet::contract]
pub mod FundManager {
    // ***************************************************************************************
    //                            IMPORT
    // ***************************************************************************************
    use super::FundOwnerInfo;
    use core::array::ArrayTrait;
    use core::traits::TryInto;
    use starknet::ContractAddress;
    use starknet::syscalls::deploy_syscall;
    use starknet::class_hash::ClassHash;
    use starknet::get_caller_address;
    use openzeppelin::utils::serde::SerializedAppend;
    use gostarkme::fund::IFundDispatcher;
    use gostarkme::fund::IFundDispatcherTrait;
    use gostarkme::constants::{funds::{fund_constants::FundConstants},};


    // ***************************************************************************************
    //                            STORAGE
    // ***************************************************************************************
    #[storage]
    struct Storage {
        owner: ContractAddress,
        current_id: u128,
        funds: LegacyMap::<u128, ContractAddress>,
        fund_class_hash: ClassHash,
        fund_owner: LegacyMap::<ContractAddress, ContractAddress>,
        fund_owners: LegacyMap::<u128, ContractAddress>,
        total_funds: u128,
    }

    // ***************************************************************************************
    //                            CONSTRUCTOR
    // ***************************************************************************************
    #[constructor]
    fn constructor(ref self: ContractState, fund_class_hash: felt252) {
        self.owner.write(get_caller_address());
        self.fund_class_hash.write(fund_class_hash.try_into().unwrap());
        self.current_id.write(1);
        self.total_funds.write(0);
    }


    // ***************************************************************************************
    //                            EVENTS
    // ***************************************************************************************
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        FundDeployed: FundDeployed,
    }

    #[derive(Drop, starknet::Event)]
    pub struct FundDeployed {
        #[key]
        pub owner: ContractAddress,
        pub fund_address: ContractAddress,
        pub fund_id: u128,
    }


    // ***************************************************************************************
    //                            EXTERNALS
    // ***************************************************************************************

    #[abi(embed_v0)]
    impl FundManagerImpl of super::IFundManager<ContractState> {
        fn new_fund(
            ref self: ContractState,
            name: ByteArray,
            goal: u256,
            evidence_link: ByteArray,
            contact_handle: ByteArray,
            reason: ByteArray,
            fund_type: u8
        ) {
            assert(goal >= FundConstants::MINIMUM_GOAL, 'Goal must be at least 500');
            let mut call_data: Array<felt252> = array![];
            Serde::serialize(@self.current_id.read(), ref call_data);
            Serde::serialize(@get_caller_address(), ref call_data);
            Serde::serialize(@name, ref call_data);
            Serde::serialize(@goal, ref call_data);
            Serde::serialize(@evidence_link, ref call_data);
            Serde::serialize(@contact_handle, ref call_data);
            Serde::serialize(@reason, ref call_data);
            Serde::serialize(@fund_type, ref call_data);
            let (new_fund_address, _) = deploy_syscall(
                self.fund_class_hash.read(), 12345, call_data.span(), false
            ).unwrap();

            self.funds.write(self.current_id.read(), new_fund_address);
            self.fund_owner.write(new_fund_address, get_caller_address());
            self
                .emit(
                    FundDeployed {
                        owner: get_caller_address(),
                        fund_address: new_fund_address,
                        fund_id: self.current_id.read()
                    }
                );

            self.current_id.write(self.current_id.read() + 1);
            self.total_funds.write(self.total_funds.read() + 1);
        }
        fn get_current_id(self: @ContractState) -> u128 {
            return self.current_id.read();
        }
        fn get_fund(self: @ContractState, id: u128) -> ContractAddress {
            return self.funds.read(id);
        }
        fn get_owner(self: @ContractState) -> ContractAddress {
            return self.owner.read();
        }
        fn get_fund_class_hash(self: @ContractState) -> ClassHash {
            return self.fund_class_hash.read();
        }
        fn get_all_fund_owners(self: @ContractState) -> Array<FundOwnerInfo> {
            let mut fund_owners: Array<FundOwnerInfo> = ArrayTrait::new();
            let total_funds: u128 = self.total_funds.read();
            let mut fund_id: u128 = 1;

            while fund_id <= total_funds {
                let fund_address: ContractAddress = self.funds.read(fund_id);
                let owner: ContractAddress = self.fund_owner.read(fund_address);
                fund_owners.append(FundOwnerInfo { fund_index: fund_id, fund_address, owner });
                fund_id += 1;
            };

            fund_owners
        }
    }
}