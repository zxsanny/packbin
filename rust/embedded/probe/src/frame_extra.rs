//! A session seals the first worked example of the contract (E1) and opens it with a replay window (a session
//! seals and opens, so one is enough: a second would only add its 600 bytes to the measured stack);
//! the MAC-only call tags and verifies the network-check example (E4).

use packbin::nostd::{Direction, Directions, FrameConfig, MacKey, MsgCtx, ReplayWindow, Session};

const KEY: [u8; 32] = [0x11; 32];
const CTX: MsgCtx = MsgCtx {
    msg_id: [0x00, 0x30, 0x10, 0x05, 0xe8, 0x03, 0x00, 0x00],
    kind: 4,
};
const AD: [u8; 11] = [
    0x00, 0x01, 0x00, 0x30, 0x10, 0x05, 0xe8, 0x03, 0x00, 0x00, 0x04,
];
const PLAIN: [u8; 12] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
const BODY: [u8; 16] = [
    0x53, 0xe9, 0xdc, 0x75, 0xfb, 0x45, 0x9d, 0x77, 0x5e, 0x62, 0x05, 0x66, 0x1c, 0xdf, 0x37, 0xff,
];
const NET_KEY: [u8; 32] = [0x22; 32];
const WAVE: [u8; 4] = [0xe8, 0x03, 0x00, 0x00];
const FRAME: [u8; 20] = [
    0xc0, 0xc1, 0xc2, 0xc3, 0xc4, 0xc5, 0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xcb, 0xcc, 0xcd, 0xce, 0xcf,
    0xd0, 0xd1, 0xd2, 0xd3,
];
const NET_TAG: [u8; 4] = [0x56, 0xdb, 0x9b, 0xec];

/// 0 when the sealed frame equals E1, opens to the plaintext with a window, is refused as a duplicate the
/// second time, and the network tag of E4 is computed and verified.
pub fn roundtrip() -> i32 {
    let config = FrameConfig {
        tag_len: 4,
        directions: Directions::NONE.with(Direction::Up),
    };
    // Loaded in place: the session is 600 bytes, and a copy of it would put that much more on the stack.
    let mut node = Session::frame_unloaded();
    if node.load_frame_in_place(&KEY, 1, config).is_err() {
        return 1;
    }
    let peer = &node;
    let mut wire = [0u8; 32];
    let n = match node.seal_frame(Direction::Up, &CTX, &AD, &[], &PLAIN, &mut wire) {
        Ok(n) => n,
        Err(fault) => return fault.error as i32 + 10,
    };
    if wire.get(..n) != Some(&BODY[..]) {
        return 2;
    }
    let mut window = ReplayWindow::new();
    let mut plain = [0u8; 32];
    let opened = peer.open_frame(
        Direction::Up,
        &CTX,
        &AD,
        &BODY,
        0,
        Some((&mut window, 7)),
        &mut plain,
    );
    match opened {
        Ok(o) if o.plain_len == PLAIN.len() && plain.get(..o.plain_len) == Some(&PLAIN[..]) => {}
        Ok(_) => return 3,
        Err(fault) => return fault.error as i32 + 30,
    }
    if peer
        .open_frame(
            Direction::Up,
            &CTX,
            &AD,
            &BODY,
            0,
            Some((&mut window, 7)),
            &mut plain,
        )
        .is_ok()
    {
        return 4;
    }
    let Ok(mac) = MacKey::derive(&NET_KEY, 7, b"net") else {
        return 5;
    };
    let mut tag = [0u8; 4];
    if mac.tag(&[&WAVE, &FRAME], &mut tag).is_err() || tag != NET_TAG {
        return 6;
    }
    if mac.verify(&[&WAVE, &FRAME], &tag) {
        0
    } else {
        7
    }
}
