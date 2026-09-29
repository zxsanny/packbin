# Restrictions — pack session

- The seed is 32 bytes. Any other length creates 0 sessions.
- The opener produces 16 bytes once per connection. Any other length joins 0 sessions.
- Each later payload is the same length as the clear packed bytes. Added bytes after the handshake: 0.
- Clear pack and unpack stay available. The position golden hex stays `4001000065cd1d00a3e1110100`.
- One session belongs to one connection. A second client gets a second session.
- The library does not open a socket, write the seed to disk, or rotate the seed on a clock.
- The six packages stay peers. None imports another.
- Archangel websocket wiring is out of this repository.
