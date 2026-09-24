mod pack;
mod unpack;

use crate::field::MapScheme;
use crate::value::{PackError, UnpackError, Values};

pub fn pack(scheme: &MapScheme, values: &Values) -> Result<Vec<u8>, PackError> {
    pack::pack(scheme, values)
}

pub fn unpack(scheme: &MapScheme, bytes: &[u8]) -> Result<Values, UnpackError> {
    unpack::unpack(scheme, bytes)
}
