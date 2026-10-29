# Loop 83 smoke step 7: run in a COPY of the tree (cwd = the copy): the Python package checks the key length after the size checks of seal and open.
p='python/src/packbin/_frame_session.py'
s=open(p).read()
# the key length check is made after the size checks of seal and open
s=s.replace('if len(material) != KEY_SIZE or not 0 <= epoch <= MAX_EPOCH:','if not 0 <= epoch <= MAX_EPOCH:',1)
s=s.replace('        return cls(config.tag_len, directions, FrameKeys(material, epoch, directions))','        made = cls(config.tag_len, directions, FrameKeys(material, epoch, directions))\n        made._bad_key = len(material) != KEY_SIZE\n        return made',1)
s=s.replace('__slots__ = ("_tag_len", "_directions", "_current", "_previous", "_closed")','__slots__ = ("_tag_len", "_directions", "_current", "_previous", "_closed", "_bad_key")',1)
s=s.replace('        self._closed = False\n','        self._closed = False\n        self._bad_key = False\n',1)
s=s.replace('        if len(out) < length:\n            return BufferFull(length)\n','        if len(out) < length:\n            return BufferFull(length)\n        if self._bad_key:\n            return BadValue("key")\n',1)
s=s.replace('        if len(out) < plain_length:\n            return BufferFull(plain_length)\n','        if len(out) < plain_length:\n            return BufferFull(plain_length)\n        if self._bad_key:\n            return BadValue("key")\n',1)
open(p,'w').write(s)
