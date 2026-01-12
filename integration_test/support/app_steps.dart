import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

Future<void> pullToRefresh(PatrolIntegrationTester $) async {
  final scrollables = find.byType(Scrollable);
  expect(scrollables, findsWidgets);

  await $.tester.drag(scrollables.first, const Offset(0, 300));
  await $.pumpAndSettle();
}

Future<void> ensureOnLoginAddForm(PatrolIntegrationTester $) async {
  await $.pumpAndSettle();

  // If we're already logged in (e.g. local dev state), log out first.
  if ($(find.text('Resources')).exists &&
      !$(find.byKey(const Key('login_serverUrl'))).exists) {
    await $(find.text('Settings')).tap();
    await $(find.text('Logout')).scrollTo().tap();
    await $(find.widgetWithText(FilledButton, 'Logout')).tap();
    await $.pumpAndSettle();
  }

  // If login add-form isn't visible, open it.
  if (!$(find.byKey(const Key('login_serverUrl'))).exists) {
    if ($(find.text('Add connection')).exists) {
      await $(find.text('Add connection')).tap();
    }
  }

  await $(find.byKey(const Key('login_serverUrl'))).waitUntilVisible();
}

Future<void> loginWith(
  PatrolIntegrationTester $, {
  required String baseUrl,
  required String apiKey,
  required String apiSecret,
}) async {
  await $.pumpAndSettle();

  // If we're already logged in (e.g. local dev state), log out first.
  if ($(find.text('Resources')).exists &&
      !$(find.byKey(const Key('login_serverUrl'))).exists) {
    await $(find.text('Settings')).tap();
    await $(find.text('Logout')).scrollTo().tap();
    await $(find.widgetWithText(FilledButton, 'Logout')).tap();
    await $.pumpAndSettle();
  }

  // If the connection already exists from a previous test run, select it and
  // avoid adding duplicate connections.
  if ($(find.text(baseUrl)).exists) {
    await $(find.text(baseUrl)).scrollTo().tap();
    await $.tester.pump(const Duration(milliseconds: 300));
    return;
  }

  await ensureOnLoginAddForm($);

  await $(find.byKey(const Key('login_serverUrl'))).scrollTo().enterText(baseUrl);
  await $(find.byKey(const Key('login_apiKey'))).scrollTo().enterText(apiKey);
  await $(find.byKey(const Key('login_apiSecret')))
      .scrollTo()
      .enterText(apiSecret);
  await $.tester.pump(const Duration(milliseconds: 300));
  await $(find.byKey(const Key('login_saveConnection'))).scrollTo().tap();
}
