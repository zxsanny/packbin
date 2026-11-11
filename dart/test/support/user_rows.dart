import 'package:packbin/packbin.dart';

/// The typed rows of the first C# README example, as Dart classes.
final class ActionName {
  ActionName([this.action = '']);
  String action;
}

final class ActionList {
  List<ActionName> actions = [];
}

final class Role {
  Role([this.roleName = '']);
  String roleName;
}

final class User {
  String username = '';
  List<Role> roles = [];
  Map<String, ActionList> access = {};
}

/// `utf8 username; list roles of {utf8 roleName}; dict access of {list
/// actions of {utf8 action}}`, with typed rows.
Scheme<User> userScheme() => rowScheme<User>(1, User.new, [
  utf8Field(
    0,
    'username',
  ).bind<User>(get: (u) => u.username, set: (u, v) => u.username = v),
  list(
    'roles',
    nestedRow<Role>('role', Role.new, [
      utf8Field(
        0,
        'roleName',
      ).bind<Role>(get: (r) => r.roleName, set: (r, v) => r.roleName = v),
    ]),
  ).bind<User>(get: (u) => u.roles, set: (u, v) => u.roles = v),
  dict(
    'access',
    nestedRow<ActionList>('list', ActionList.new, [
      list(
        'actions',
        nestedRow<ActionName>('name', ActionName.new, [
          utf8Field(
            0,
            'action',
          ).bind<ActionName>(get: (a) => a.action, set: (a, v) => a.action = v),
        ]),
      ).bind<ActionList>(get: (l) => l.actions, set: (l, v) => l.actions = v),
    ]),
  ).bind<User>(get: (u) => u.access, set: (u, v) => u.access = v),
]);

/// The same scheme for map rows.
Scheme<Map<String, Object?>> userMapScheme() => scheme(1, [
  utf8Field(0, 'username'),
  list('roles', nested('role', [utf8Field(0, 'roleName')])),
  dict(
    'access',
    nested('list', [
      list('actions', nested('name', [utf8Field(0, 'action')])),
    ]),
  ),
]);

/// The README example's packet.
const userHex =
    '01 03 a9 28 80 02 00 03 0b a8 18 04 89 29 75 60 02 00 03 6a e9 c8'
    '02 00 03 2b 01 28 03 48 51 64 04 ca 25 f0 00 01 00 04 8b bc 2c 80';

User ada() {
  ActionList actions(List<String> names) =>
      ActionList()..actions = [for (final n in names) ActionName(n)];
  return User()
    ..username = 'ada'
    ..roles = [Role('user'), Role('admin')]
    ..access = {
      'map': actions(['read', 'edit']),
      'store': actions(['write']),
    };
}
