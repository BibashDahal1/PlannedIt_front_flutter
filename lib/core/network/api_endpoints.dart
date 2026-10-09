class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const String signupRequest = '/auth/signup/request';
  static const String signupVerify = '/auth/signup/verify';
  static const String loginRequest = '/auth/login/request';
  static const String loginVerify = '/auth/login/verify';
  static const String tokenRefresh = '/auth/token/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/users/me';

  // Activities
  static const String categories = '/categories';
  static const String activities = '/activities';
  static const String myActivities = '/activities/mine';
  static String activityDetail(String id) => '/activities/$id';

  // Join requests
  static String activityJoinRequests(String activityId) =>
      '/activities/$activityId/join-requests';
  static const String myJoinRequests = '/join-requests/mine';
  static String joinRequestDetail(String id) => '/join-requests/$id';
  static String joinRequestAccept(String id) => '/join-requests/$id/accept';
  static String joinRequestDecline(String id) => '/join-requests/$id/decline';
  static String joinRequestWithdraw(String id) => '/join-requests/$id/withdraw';

  // Groups
  static const String myGroups = '/groups/mine';
  static String groupDetail(String id) => '/groups/$id';
  static String groupTeams(String id) => '/groups/$id/teams';
  static String groupExpenses(String id) => '/groups/$id/expenses';
  static String groupExpense(String groupId, String expenseId) =>
      '/groups/$groupId/expenses/$expenseId';

  // Social groups (NEW)
  static const String socialGroups = '/social-groups';
  static const String socialGroupEligibleMembers =
      '/social-groups/eligible-members';
  static const String mySocialGroups = '/social-groups/mine';
  static String socialGroupDetail(String id) => '/social-groups/$id';
  static String socialGroupMembers(String id) => '/social-groups/$id/members';
  static String socialGroupMember(String id, String userId) =>
      '/social-groups/$id/members/$userId';
  static String socialGroupChatToken(String id) =>
      '/social-groups/$id/chat-token';
  static String socialGroupMessages(String id) => '/social-groups/$id/messages';

  // Trust / ratings / moderation
  static String activityComplete(String activityId) =>
      '/activities/$activityId/complete';
  static const String pendingRatings = '/ratings/pending';
  static String activityRatings(String activityId) =>
      '/activities/$activityId/ratings';
  static String publicProfile(String userId) => '/users/$userId/public-profile';
  static const String reports = '/reports';
  static const String blocks = '/blocks';
  static String groupChatToken(String groupId) => '/groups/$groupId/chat-token';
  static String groupMessages(String groupId) => '/groups/$groupId/messages';
  static const String deviceRegister = '/devices/register';
  static String activityCancel(String id) => '/activities/$id/cancel';
  static const String activitiesNearby = '/activities/nearby';

  static const String legalDocuments = '/legal';
  static String legalDocument(String documentType) => '/legal/$documentType';

  static const String socialGroupInvitations = '/social-groups/invitations';
  static String socialGroupInvitationAccept(String id) =>
      '/social-groups/invitations/$id/accept';
  static String socialGroupInvitationDecline(String id) =>
      '/social-groups/invitations/$id/decline';
  static String socialGroupInvitationCancel(
    String groupId,
    String invitationId,
  ) => '/social-groups/$groupId/invitations/$invitationId';
}
