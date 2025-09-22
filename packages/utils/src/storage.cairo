use sai_core_utils::poseidon_hash_single;
use starknet::storage_access::{
    StorageBaseAddress, StorePacking, storage_address_from_base,
    storage_address_from_base_and_offset, storage_base_address_from_felt252,
};
use starknet::syscalls::{storage_read_syscall, storage_write_syscall};
use starknet::{StorageAddress, SyscallResult};
// pub fn read_short_array_from_address<T, impl TStore: Store<T>, +Drop<T>>(
//     address: StorageAddress,
// ) -> SyscallResult<Array<T>> {
//     let length_felt = storage_read_syscall(0, address)?;
//     let length: usize = StorePacking::unpack(length_felt);
//     let elements_address = poseidon_hash_single(address);
//     let mut array: Array<T> = Default::default();
//     let size: u32 = Store::<T>::size().into();
//     for i in 0..length {
//         let element_address = storage_base_address_from_felt252(
//             elements_address + (size * i).into(),
//         );

//         array.append(Store::read(0, element_address)?);
//     }
//     Ok(array)
// }

// pub fn write_short_array_to_address<T, impl TStore: Store<T>, +Drop<T>>(
//     address: StorageAddress, array: Array<T>,
// ) -> SyscallResult<()> {
//     let length: usize = array.len();
//     storage_write_syscall(0, address, StorePacking::pack(length))?;
//     let elements_address = poseidon_hash_single(address);
//     let size: u32 = TStore::size().into();
//     for (i, element) in array.into_iter().enumerate() {
//         let element_address = storage_base_address_from_felt252(
//             elements_address + (size * i).into(),
//         );
//         TStore::write(0, element_address, element)?;
//     }
//     Ok(())
// }

pub trait ShortArrayReadWriteTrait<T> {
    fn read_short_array(address: StorageAddress) -> SyscallResult<Array<T>>;
    fn write_short_array(address: StorageAddress, array: Array<T>) -> SyscallResult<()>;
}

pub mod short_array {
    use starknet::StorageAddress;
    use super::*;

    pub impl ShortArrayReadWrite<
        T, impl TStore: starknet::Store<T>, +Drop<T>,
    > of ShortArrayReadWriteTrait<T> {
        fn read_short_array(address: StorageAddress) -> SyscallResult<Array<T>> {
            let length_felt = storage_read_syscall(0, address)?;
            let length: usize = StorePacking::unpack(length_felt);
            let elements_address = poseidon_hash_single(address);
            let mut array: Array<T> = Default::default();
            let size: u32 = TStore::size().into();
            for i in 0..length {
                let element_address = storage_base_address_from_felt252(
                    elements_address + (size * i).into(),
                );

                array.append(TStore::read(0, element_address)?);
            }
            Ok(array)
        }
        fn write_short_array(address: StorageAddress, array: Array<T>) -> SyscallResult<()> {
            let length: usize = array.len();
            storage_write_syscall(0, address, StorePacking::pack(length))?;
            let elements_address = poseidon_hash_single(address);
            let size: u32 = TStore::size().into();
            for (i, element) in array.into_iter().enumerate() {
                let element_address = storage_base_address_from_felt252(
                    elements_address + (size * i).into(),
                );
                TStore::write(0, element_address, element)?;
            }
            Ok(())
        }
    }
}


pub impl ShortArrayStore<
    T, impl AStore: ShortArrayReadWriteTrait<T>, +Drop<T>,
> of starknet::Store<Array<T>> {
    fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<Array<T>> {
        AStore::read_short_array(storage_address_from_base(base))
    }

    fn write(address_domain: u32, base: StorageBaseAddress, value: Array<T>) -> SyscallResult<()> {
        ShortArrayReadWriteTrait::write_short_array(storage_address_from_base(base), value)
    }

    fn read_at_offset(
        address_domain: u32, base: StorageBaseAddress, offset: u8,
    ) -> SyscallResult<Array<T>> {
        ShortArrayReadWriteTrait::read_short_array(
            storage_address_from_base_and_offset(base, offset),
        )
    }

    fn write_at_offset(
        address_domain: u32, base: StorageBaseAddress, offset: u8, value: Array<T>,
    ) -> SyscallResult<()> {
        ShortArrayReadWriteTrait::write_short_array(
            storage_address_from_base_and_offset(base, offset), value,
        )
    }

    #[inline]
    fn size() -> u8 {
        1_u8
    }
}

pub impl FeltArrayReadWrite = short_array::ShortArrayReadWrite<felt252>;
