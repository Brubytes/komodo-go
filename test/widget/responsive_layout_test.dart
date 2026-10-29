import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komodo_go/composition/home/widgets/home_dashboard_layout.dart';
import 'package:komodo_go/core/theme/app_theme.dart';
import 'package:komodo_go/core/ui/app_icons.dart';
import 'package:komodo_go/core/widgets/detail/detail_widgets.dart';

void _setWidth(WidgetTester tester, double width, {double height = 900}) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(width, height);
  addTearDown(tester.view.reset);
}

Widget _app(Widget body) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: Scaffold(body: body),
);

Widget _box(String key) => SizedBox(key: ValueKey(key), height: 80);

void main() {
  group('HomeDashboardLayout', () {
    Widget layout() => _app(
      HomeDashboardLayout(
        attention: _box('attention'),
        serverOverview: _box('overview'),
        alerts: _box('alerts'),
        opsPulse: _box('ops'),
      ),
    );

    testWidgets('stacks sections in one column at 400', (tester) async {
      _setWidth(tester, 400);
      await tester.pumpWidget(layout());

      expect(find.byKey(const ValueKey('home_column_primary')), findsNothing);
      final order = [
        for (final k in ['attention', 'overview', 'alerts', 'ops'])
          tester.getTopLeft(find.byKey(ValueKey(k))),
      ];
      for (final p in order) {
        expect(p.dx, order.first.dx);
      }
      expect(
        order.map((p) => p.dy).toList(),
        [...order.map((p) => p.dy)]..sort(),
      );
    });

    testWidgets('uses two columns at 1000', (tester) async {
      _setWidth(tester, 1000);
      await tester.pumpWidget(layout());

      expect(find.byKey(const ValueKey('home_column_primary')), findsOneWidget);
      final attention = tester.getTopLeft(
        find.byKey(const ValueKey('attention')),
      );
      final alerts = tester.getTopLeft(find.byKey(const ValueKey('alerts')));
      final ops = tester.getTopLeft(find.byKey(const ValueKey('ops')));
      final overview = tester.getSize(find.byKey(const ValueKey('overview')));
      expect(attention.dx, alerts.dx);
      expect(ops.dx, greaterThan(attention.dx + 300));
      expect(ops.dy, attention.dy);
      // Stats span the full content width above the columns.
      expect(overview.width, greaterThan(900));
    });

    testWidgets('switches at 720 (iPad portrait yes, mini portrait no)', (
      tester,
    ) async {
      expect(HomeDashboardLayout.isTwoColumn(754), isTrue);
      expect(HomeDashboardLayout.isTwoColumn(720), isTrue);
      expect(HomeDashboardLayout.isTwoColumn(664), isFalse);
    });

    testWidgets('caps content width and centers it on very wide panes', (
      tester,
    ) async {
      _setWidth(tester, 1600);
      await tester.pumpWidget(layout());

      final size = tester.getSize(find.byKey(const ValueKey('overview')));
      expect(size.width, homeDashboardMaxWidth);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('overview'))).dx,
        (1600 - homeDashboardMaxWidth) / 2,
      );
    });

    testWidgets('follows the local width, not the window', (tester) async {
      _setWidth(tester, 1000);
      await tester.pumpWidget(
        _app(
          Row(
            children: [
              SizedBox(
                width: 400,
                child: HomeDashboardLayout(
                  attention: _box('attention'),
                  serverOverview: _box('overview'),
                  alerts: _box('alerts'),
                  opsPulse: _box('ops'),
                ),
              ),
            ],
          ),
        ),
      );
      expect(find.byKey(const ValueKey('home_column_primary')), findsNothing);
    });
  });

  group('DetailResponsiveColumns', () {
    Widget columns() => _app(
      SingleChildScrollView(
        child: DetailResponsiveColumns(
          children: [
            for (var i = 0; i < 4; i++) _box('c$i'),
          ],
        ),
      ),
    );

    testWidgets('one column at 400', (tester) async {
      _setWidth(tester, 400);
      await tester.pumpWidget(columns());
      expect(find.byKey(const ValueKey('detail_columns_1')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('c0'))).dx,
        tester.getTopLeft(find.byKey(const ValueKey('c3'))).dx,
      );
    });

    testWidgets('two columns at 1000, dealt alternately', (tester) async {
      _setWidth(tester, 1000);
      await tester.pumpWidget(columns());
      expect(find.byKey(const ValueKey('detail_columns_2')), findsOneWidget);
      final c0 = tester.getTopLeft(find.byKey(const ValueKey('c0')));
      final c1 = tester.getTopLeft(find.byKey(const ValueKey('c1')));
      final c2 = tester.getTopLeft(find.byKey(const ValueKey('c2')));
      expect(c1.dx, greaterThan(c0.dx));
      expect(c1.dy, c0.dy);
      expect(c2.dx, c0.dx);
      expect(c2.dy, greaterThan(c0.dy));
    });
  });

  group('DetailResourceHeader facts', () {
    Widget header() => _app(
      SingleChildScrollView(
        child: DetailResourceHeader(
          facts: [
            for (var i = 0; i < 4; i++)
              DetailFact(icon: AppIcons.server, label: 'Fact $i', value: 'v$i'),
          ],
        ),
      ),
    );

    testWidgets('single column at 400', (tester) async {
      _setWidth(tester, 400);
      await tester.pumpWidget(header());
      expect(
        find.byKey(const ValueKey('detail_header_fact_columns')),
        findsNothing,
      );
    });

    testWidgets('two columns at 1000', (tester) async {
      _setWidth(tester, 1000);
      await tester.pumpWidget(header());
      expect(
        find.byKey(const ValueKey('detail_header_fact_columns')),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.text('Fact 2')).dy,
        tester.getTopLeft(find.text('Fact 0')).dy,
      );
    });
  });

  group('DetailTabScrollView', () {
    Widget scroll({double? maxWidth}) => _app(
      NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverOverlapAbsorber(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),
        ],
        body: Builder(
          builder: (context) => maxWidth == null
              ? DetailTabScrollView.box(child: _box('body'))
              : DetailTabScrollView.box(
                  maxContentWidth: maxWidth,
                  child: _box('body'),
                ),
        ),
      ),
    );

    testWidgets('fills a narrow pane', (tester) async {
      _setWidth(tester, 400);
      await tester.pumpWidget(scroll());
      expect(tester.getSize(find.byKey(const ValueKey('body'))).width, 368);
    });

    testWidgets('caps and centers at the readable width', (tester) async {
      _setWidth(tester, 1400);
      await tester.pumpWidget(scroll());
      final body = find.byKey(const ValueKey('body'));
      expect(tester.getSize(body).width, detailContentMaxWidth);
      expect(tester.getTopLeft(body).dx, (1400 - detailContentMaxWidth) / 2);
    });

    testWidgets('infinite max width spans the pane', (tester) async {
      _setWidth(tester, 1400);
      await tester.pumpWidget(scroll(maxWidth: double.infinity));
      expect(tester.getSize(find.byKey(const ValueKey('body'))).width, 1368);
    });
  });
}
