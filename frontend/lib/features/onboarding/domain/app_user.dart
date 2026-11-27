enum UserRole {
  parent('PARENT'),
  child('CHILD');

  const UserRole(this.apiValue);
  final String apiValue;

  static UserRole fromApi(String value) => UserRole.values.firstWhere(
    (role) => role.apiValue == value,
    orElse: () => throw FormatException('알 수 없는 role: $value'),
  );
}

enum PairingStatus {
  paired('PAIRED'),
  unpaired('UNPAIRED');

  const PairingStatus(this.apiValue);
  final String apiValue;

  static PairingStatus fromApi(String value) => PairingStatus.values.firstWhere(
    (status) => status.apiValue == value,
    orElse: () => throw FormatException('알 수 없는 pairingStatus: $value'),
  );
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.role,
    required this.pairingStatus,
    this.partnerName,
  });

  final String id;
  final String name;
  final UserRole role;
  final PairingStatus pairingStatus;

  /// 지금 연결된 상대가 서비스에 등록한 이름. 연결 전이거나 구버전 서버면 null.
  final String? partnerName;

  bool get isPaired => pairingStatus == PairingStatus.paired;

  AppUser copyWith({PairingStatus? pairingStatus}) => AppUser(
    id: id,
    name: name,
    role: role,
    pairingStatus: pairingStatus ?? this.pairingStatus,
    partnerName: partnerName,
  );

  // API 계약 5.1 `user` 객체와 같은 모양. 기기 저장에도 그대로 쓴다.
  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    name: json['name'] as String,
    role: UserRole.fromApi(json['role'] as String),
    pairingStatus: PairingStatus.fromApi(json['pairingStatus'] as String),
    // 이전에 기기에 저장한 정보에는 없으므로 null로 읽는다
    partnerName: json['partnerName'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'role': role.apiValue,
    'pairingStatus': pairingStatus.apiValue,
    'partnerName': partnerName,
  };
}
