part of 'hostile_packs.dart';

/// AZ-4301, contract scheme-depth: 256 levels build and pack the bytes they
/// packed before the limit. The chains are written by a loop.
final Map<String, HostilePack> _depthPacks = {
  'pack_depth_when_256': HostilePack(
    () => _s(whenChain(256)),
    () => {'a': 1, 'b': 7},
  ),
  'pack_depth_group_256': HostilePack(
    () => _s(groupChain(256)),
    () => groupRow(256),
  ),
};
