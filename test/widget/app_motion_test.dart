import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/core/theme/app_page_transitions.dart';
import 'package:komodo_go/core/ui/app_motion.dart';

Widget _host(Widget child, {bool reduced = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Scaffold(body: child),
    ),
  );
}

Finder _within(Type host, Type matching) => find.descendant(
  of: find.byType(host),
  matching: find.byType(matching),
);

void main() {
  group('AppMotion', () {
    test('stagger steps by 30ms and caps at 150ms', () {
      expect(AppMotion.stagger(0), Duration.zero);
      expect(AppMotion.stagger(2), const Duration(milliseconds: 60));
      expect(AppMotion.stagger(50), const Duration(milliseconds: 150));
    });
  });

  group('AppFadeSlide', () {
    testWidgets('animates in normal mode', (tester) async {
      await tester.pumpWidget(_host(const AppFadeSlide(child: Text('x'))));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.text('x'), findsOneWidget);
    });

    testWidgets('does not animate when reduced', (tester) async {
      await tester.pumpWidget(
        _host(const AppFadeSlide(child: Text('x')), reduced: true),
      );
      expect(tester.hasRunningAnimations, isFalse);
      expect(_within(AppFadeSlide, FadeTransition), findsNothing);
    });

    testWidgets('delay is part of the timeline without timers', (tester) async {
      await tester.pumpWidget(
        _host(
          const AppFadeSlide(
            delay: Duration(milliseconds: 100),
            child: Text('x'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      final fade = tester.widget<FadeTransition>(
        _within(AppFadeSlide, FadeTransition),
      );
      expect(fade.opacity.value, 0);
      await tester.pumpAndSettle();
    });
  });

  group('AppSwitcher', () {
    Widget switcher(String text, {bool reduced = false}) => _host(
      AppSwitcher(child: Text(text, key: ValueKey(text))),
      reduced: reduced,
    );

    testWidgets('animates a change in normal mode', (tester) async {
      await tester.pumpWidget(switcher('a'));
      await tester.pumpWidget(switcher('b'));
      await tester.pump(const Duration(milliseconds: 10));
      expect(tester.hasRunningAnimations, isTrue);
      expect(find.text('a'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('a'), findsNothing);
      expect(_within(AppSwitcher, AnimatedSize), findsOneWidget);
    });

    testWidgets('reduced: fade only, no size or scale', (tester) async {
      await tester.pumpWidget(switcher('a', reduced: true));
      await tester.pumpWidget(switcher('b', reduced: true));
      expect(_within(AppSwitcher, AnimatedSize), findsNothing);
      expect(_within(AppSwitcher, ScaleTransition), findsNothing);
      await tester.pump(AppMotion.fast + const Duration(milliseconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.text('a'), findsNothing);
    });
  });

  group('AppExpand', () {
    Widget expand({required bool open, bool reduced = false}) => _host(
      AppExpand(expanded: open, child: const SizedBox(height: 100)),
      reduced: reduced,
    );

    testWidgets('animates size in normal mode', (tester) async {
      await tester.pumpWidget(expand(open: false));
      await tester.pumpWidget(expand(open: true));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.hasRunningAnimations, isTrue);
      final h = tester.getSize(find.byType(AppExpand)).height;
      expect(h, inInclusiveRange(0, 100));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AppExpand)).height, 100);
    });

    testWidgets('jumps when reduced', (tester) async {
      await tester.pumpWidget(expand(open: false, reduced: true));
      await tester.pumpWidget(expand(open: true, reduced: true));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.getSize(find.byType(AppExpand)).height, 100);
    });

    testWidgets('chevron rotates in sync, instantly when reduced', (
      tester,
    ) async {
      Widget chevron({required bool e, required bool r}) =>
          _host(AppChevron(expanded: e), reduced: r);
      await tester.pumpWidget(chevron(e: false, r: false));
      await tester.pumpWidget(chevron(e: true, r: false));
      await tester.pump(const Duration(milliseconds: 10));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();

      await tester.pumpWidget(chevron(e: false, r: true));
      await tester.pumpWidget(chevron(e: true, r: true));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('AppAnimatedValue', () {
    Widget value(String v) => _host(AppAnimatedValue.text(v));

    testWidgets('does not animate on first build', (tester) async {
      await tester.pumpWidget(value('1'));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('animates when value changes', (tester) async {
      await tester.pumpWidget(value('1'));
      await tester.pumpWidget(value('2'));
      await tester.pump(const Duration(milliseconds: 10));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('same value does not animate', (tester) async {
      await tester.pumpWidget(value('1'));
      await tester.pumpWidget(value('1'));
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('AppPressable', () {
    testWidgets('scales on pointer down and restores', (tester) async {
      await tester.pumpWidget(
        _host(
          const Center(
            child: AppPressable(child: SizedBox(width: 100, height: 100)),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AppPressable)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        AppMotion.pressScale,
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    });

    testWidgets('no scale when reduced', (tester) async {
      await tester.pumpWidget(
        _host(const AppPressable(child: SizedBox()), reduced: true),
      );
      expect(find.byType(AnimatedScale), findsNothing);
    });
  });

  group('AppListIntro', () {
    testWidgets('plays only first build and only first N items', (
      tester,
    ) async {
      final intro = AppListIntro();
      Widget list(int count) => _host(
        Column(
          children: [
            for (var i = 0; i < count; i++) intro.wrap(i, Text('item $i')),
          ],
        ),
      );

      await tester.pumpWidget(list(12));
      // 8 intro items run an animation, the remaining 4 do not.
      expect(_within(AppFadeSlide, FadeTransition), findsNWidgets(8));
      await tester.pumpAndSettle();
      expect(intro.introPending, isFalse);

      // Rebuild with the same items: nothing replays.
      await tester.pumpWidget(list(12));
      expect(tester.hasRunningAnimations, isFalse);

      // A new item after the intro fades in without replaying others.
      await tester.pumpWidget(list(13));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('shouldPlay and delay follow limit and stagger', (
      tester,
    ) async {
      final intro = AppListIntro();
      expect(intro.shouldPlay(0), isTrue);
      expect(intro.shouldPlay(AppMotion.introItemLimit), isFalse);
      expect(intro.delay(3), AppMotion.stagger(3));
      await tester.pumpWidget(_host(intro.wrap(0, const Text('a'))));
      await tester.pumpAndSettle();
      expect(intro.shouldPlay(0), isFalse);
      expect(intro.delay(3), Duration.zero);
    });

    testWidgets('does not animate when reduced', (tester) async {
      final intro = AppListIntro();
      await tester.pumpWidget(
        _host(intro.wrap(0, const Text('a')), reduced: true),
      );
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('AppPageTransitionsBuilder', () {
    Future<void> pushPage(WidgetTester tester, {required bool reduced}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            pageTransitionsTheme: PageTransitionsTheme(
              builders: {
                for (final p in TargetPlatform.values)
                  p: const AppPageTransitionsBuilder(),
              },
            ),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: child!,
          ),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('second')),
                ),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
    }

    testWidgets('slides (Cupertino) in normal mode', (tester) async {
      await pushPage(tester, reduced: false);
      expect(find.byType(CupertinoPageTransition), findsWidgets);
      await tester.pumpAndSettle();
    });

    testWidgets('fades when reduced', (tester) async {
      await pushPage(tester, reduced: true);
      expect(find.byType(CupertinoPageTransition), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('second'), findsOneWidget);
    });
  });
}
