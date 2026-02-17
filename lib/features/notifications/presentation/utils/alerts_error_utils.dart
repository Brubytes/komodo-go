bool isAlertsPermissionError(Object error) {
  final normalized = error.toString().toLowerCase();
  const markers = <String>[
    'permission',
    'forbidden',
    'not authorized',
    'unauthorized',
    'access denied',
    'super admin',
    'insufficient',
  ];
  return markers.any(normalized.contains);
}

String alertsUnavailableTitle(Object error) {
  if (isAlertsPermissionError(error)) {
    return 'Alerts unavailable for this account';
  }
  return 'Alerts temporarily unavailable';
}

String alertsUnavailableMessage(Object error) {
  if (isAlertsPermissionError(error)) {
    return 'This account cannot read alerts. You can still use the Updates feed.';
  }
  return 'Alerts could not be loaded right now. You can keep working from the Updates feed.';
}
