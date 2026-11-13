abstract class AccountRepository {
  /// 회원 탈퇴를 요청한다. (계약 5.13 초안) 성공하면 서버가 삭제 작업을 시작한 것이다.
  Future<void> deleteAccount();
}
