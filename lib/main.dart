import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rfw/formats.dart';
import 'package:rfw/rfw.dart';

void main() {
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RFW Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'RFW Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final Runtime _runtime = Runtime();
  late DynamicContent _data;

  bool _isFetching = false;

  static const LibraryName coreName = LibraryName(<String>['core', 'widgets']);
  static const LibraryName appName = LibraryName(<String>[
    'app',
  ]); // your local lib name
  static const LibraryName mainName = LibraryName(<String>['main']);

  @override
  void initState() {
    super.initState();
    _runtime
      ..update(coreName, createCoreWidgets())
      ..update(appName, createAppWidgets());

    // 2) Initial content with loader visible
    _data = DynamicContent(<String, Object>{
      'apiResponse': <String, Object>{
        'status': 'idle',
        'isLoading': true,
        'response': <Object>[],
      },
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: FutureBuilder(
        future: fetchRfwData(),
        builder: (context, asyncSnapshot) {
          if (asyncSnapshot.data != null) {
            //_runtime.update(mainName, _remoteWidgets);
            _runtime.update(mainName, asyncSnapshot.data as WidgetLibrary);
            return RemoteWidget(
              runtime: _runtime,
              data: _data,
              widget: const FullyQualifiedWidgetName(mainName, 'root'),
              onEvent: (String name, DynamicMap arguments) async {
                if (name == 'item_tap') {
                  final who = (arguments['title'] ?? 'there').toString();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Hi $who 👋'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  return;
                }

                if (name == 'rfw_loaded') {
                  if (_isFetching)
                    return; // ignore while an earlier fetch is running
                  _isFetching = true;

                  // Show loader immediately
                  _data.update('apiResponse', <String, Object>{
                    'status': 'loading',
                    'isLoading': true,
                    'response': <Object>[],
                  });

                  if (arguments['apiCallType'] == 'rest') {
                    final response = await fetchData(
                      arguments['requestUrl'].toString(),
                    );

                    if (response['status'] == 'success') {
                      _data.update('apiResponse', <String, Object>{
                        'status': 'success',
                        'isLoading': false,
                        'response': response['response'],
                      });
                    } else {
                      _data.update('apiResponse', <String, Object>{
                        'status': 'failure',
                        'isLoading': false,
                        'response': <Object>[],
                      });
                    }
                  }

                  _isFetching = false;
                }
              },
            );
          } else {
            return SizedBox();
          }
        },
      ),
    );
  }

  Future<Map<String, dynamic>> fetchData(String requestURL) async {
    final url = Uri.parse(requestURL);
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {"status": "success", "response": data};
      } else {
        return {"status": "failure"};
      }
    } catch (_) {
      return {"status": "failure"};
    }
  }

  Future<RemoteWidgetLibrary?> fetchRfwData() async {
    final hListExample = Uri.parse(
      "https://res.cloudinary.com/curiozing/raw/upload/v1754219870/grftexample_vziuns.rfw",
    );
    final vListExample = Uri.parse(
      "https://res.cloudinary.com/curiozing/raw/upload/v1754234779/grftexample1_pq2opf.rfw",
    );
    final vPageExample = Uri.parse(
      "https://res.cloudinary.com/curiozing/raw/upload/v1754237037/grftexample2_xxsgdw.rfw",
    );

    try {
      final response = await http.get(hListExample);
      if (response.statusCode == 200) {
        final data = response.bodyBytes;
        return decodeLibraryBlob(data);
      } else {
        return null;
      }
    } catch (_) {
      return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Local widgets exposed to remote via `import app;`
// ─────────────────────────────────────────────────────────────────────────────

class _OnInit extends StatefulWidget {
  const _OnInit({required this.onInit, required this.child});

  final VoidCallback? onInit;
  final Widget child;

  @override
  State<_OnInit> createState() => _OnInitState();
}

class _OnInitState extends State<_OnInit> {
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_fired) {
        _fired = true;
        widget.onInit?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ShowWhen extends StatelessWidget {
  const _ShowWhen({required this.show, this.child, this.fallback});

  final bool show;
  final Widget? child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) => show
      ? (child ?? const SizedBox.shrink())
      : (fallback ?? const SizedBox.shrink());
}

typedef IntCallback = void Function(int);

LocalWidgetLibrary createAppWidgets() {
  return LocalWidgetLibrary(<String, LocalWidgetBuilder>{
    'OnInit': (BuildContext context, DataSource source) {
      final child =
          source.optionalChild(const <Object>['child']) ??
          const SizedBox.shrink();
      final onInit = source.voidHandler(const <Object>['onInit']);
      return _OnInit(onInit: onInit, child: child);
    },

    // ShowWhen: reads `when:` (preferred) or `show:` for backward-compat
    'ShowWhen': (BuildContext context, DataSource source) {
      final bool show =
          (source.v<bool>(const <Object>['when']) ??
          source.v<bool>(const <Object>['show']) ??
          false);
      final Widget? child = source.optionalChild(const <Object>['child']);
      final Widget? fallback = source.optionalChild(const <Object>['fallback']);
      return _ShowWhen(show: show, child: child, fallback: fallback);
    },

    'ShowIfEqString': (BuildContext context, DataSource source) {
      final String? left = source.v<String>(const <Object>['left']);
      final String? right = source.v<String>(const <Object>['right']);
      final bool ignoreCase =
          source.v<bool>(const <Object>['ignoreCase']) ?? false;
      final Widget? child = source.optionalChild(const <Object>['child']);
      final Widget? fallback = source.optionalChild(const <Object>['fallback']);
      return _ShowIfEqString(
        left: left,
        right: right,
        ignoreCase: ignoreCase,
        fallback: fallback,
        child: child,
      );
    },

    'VerticalPager': (BuildContext context, DataSource source) {
      // Scalars must be read as int/double/bool/String (not 'num')
      final int initialPage = source.v<int>(<Object>['initialPage']) ?? 0;

      // Read as double first; if null, try int and convert
      double viewportMinus =
          source.v<double>(<Object>['viewportMinus']) ??
          (source.v<int>(<Object>['viewportMinus'])?.toDouble() ?? 0.0);

      // Optional absolute page height override; if provided, it wins
      final double? pageHeightArg =
          source.v<double>(<Object>['pageHeight']) ??
          source.v<int>(<Object>['pageHeight'])?.toDouble();

      // Children: each is one "page"
      final List<Widget> pages = source.childList(<Object>['children']);

      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Compute effective page height
          double baseHeight =
              pageHeightArg ?? (constraints.maxHeight - viewportMinus);

          if (!baseHeight.isFinite) baseHeight = constraints.maxHeight;
          final double effectiveHeight = baseHeight.clamp(
            0.0,
            constraints.maxHeight,
          );

          final List<Widget> sizedPages = <Widget>[
            for (final Widget child in pages)
              SizedBox(
                width: constraints.maxWidth,
                height: effectiveHeight,
                child: child,
              ),
          ];

          return PageView(
            controller: PageController(initialPage: initialPage),
            scrollDirection: Axis.vertical,
            pageSnapping: true,
            children: sizedPages,
          );
        },
      );
    },
    'HorizontalPager': (BuildContext context, DataSource source) {
      // ── Scalars
      final int initialPage = source.v<int>(['initialPage']) ?? 0;

      final double viewportFraction =
          source.v<double>(['viewportFraction']) ??
          (source.v<int>(['viewportFraction'])?.toDouble() ?? 0.82); // peek

      final bool pageSnapping = source.v<bool>(['pageSnapping']) ?? true;
      final bool reverse = source.v<bool>(['reverse']) ?? false;
      final bool padEnds = source.v<bool>(['padEnds']) ?? true;

      // Height control
      final double? heightArg =
          source.v<double>(['height']) ?? source.v<int>(['height'])?.toDouble();

      final double viewportMinus =
          source.v<double>(['viewportMinus']) ??
          (source.v<int>(['viewportMinus'])?.toDouble() ?? 0.0);

      // Spacing & focus visuals
      final double itemSpacing =
          source.v<double>(['itemSpacing']) ??
          (source.v<int>(['itemSpacing'])?.toDouble() ?? 12.0);

      final double minScale =
          source.v<double>(['minScale']) ??
          (source.v<int>(['minScale'])?.toDouble() ?? 0.90); // side size

      final double maxScale =
          source.v<double>(['maxScale']) ??
          (source.v<int>(['maxScale'])?.toDouble() ?? 1.10); // center size

      final double sideOpacity =
          source.v<double>(['sideOpacity']) ??
          (source.v<int>(['sideOpacity'])?.toDouble() ??
              1.0); // e.g., 0.8 to dim sides

      // Typed handler generator: send a map {index: <int>}
      final IntCallback? onPageChanged = source.handler<IntCallback>(
        ['onPageChanged'],
        (trigger) {
          return (int index) => trigger(<String, Object?>{'index': index});
        },
      );

      // Children (cards)
      final List<Widget> pages = source.childList(['children']);

      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Effective height for the band
          double effectiveHeight;
          if (heightArg != null) {
            effectiveHeight = heightArg;
          } else {
            double h = constraints.maxHeight;
            if (!h.isFinite) h = 240.0;
            double candidate = h - viewportMinus;
            if (!candidate.isFinite || candidate <= 0) candidate = 240.0;
            effectiveHeight = candidate;
          }

          // Build controller with peek
          final controller = PageController(
            initialPage: initialPage,
            viewportFraction: viewportFraction.clamp(0.1, 1.0),
          );

          // Use builder so we can scale per-index based on controller.page
          return SizedBox(
            height: effectiveHeight,
            child: PageView.builder(
              controller: controller,
              scrollDirection: Axis.horizontal,
              pageSnapping: pageSnapping,
              reverse: reverse,
              padEnds: padEnds,
              itemCount: pages.length,
              onPageChanged: (int index) => onPageChanged?.call(index),
              itemBuilder: (context, index) {
                return AnimatedBuilder(
                  animation: controller,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: itemSpacing / 2),
                    child: pages[index],
                  ),
                  builder: (context, child) {
                    // Current scroll position → compute distance from this index
                    double page = initialPage.toDouble();
                    if (controller.hasClients &&
                        controller.position.haveDimensions) {
                      page =
                          controller.page ?? controller.initialPage.toDouble();
                    }

                    final double dist = (page - index).abs();
                    // t = 1 at center, → 0 when ≥1 page away
                    final double t = (1.0 - dist).clamp(0.0, 1.0);
                    final double scale = (minScale + (maxScale - minScale) * t)
                        .clamp(minScale, maxScale);
                    final double opacity =
                        (sideOpacity + (1.0 - sideOpacity) * t).clamp(0.0, 1.0);

                    // Scale around center; allow slight overflow visually
                    return Center(
                      child: Opacity(
                        opacity: opacity,
                        child: Transform.scale(
                          scale: scale,
                          alignment: Alignment.center,
                          child: child,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      );
    },
  });
}

class _ShowIfEqString extends StatelessWidget {
  const _ShowIfEqString({
    this.left,
    this.right,
    this.ignoreCase = false,
    this.child,
    this.fallback,
  });

  final String? left;
  final String? right;
  final bool ignoreCase;
  final Widget? child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    String? a = left;
    String? b = right;
    if (ignoreCase) {
      a = a?.toLowerCase();
      b = b?.toLowerCase();
    }
    final bool show = (a != null && b != null && a == b);
    return show
        ? (child ?? const SizedBox.shrink())
        : (fallback ?? const SizedBox.shrink());
  }
}

final RemoteWidgetLibrary _remoteWidgets = parseLibraryFile(r'''
import core.widgets;
import app;  // exposes HorizontalPager + OnInit + ShowWhen + ShowIfEqString

widget root = OnInit(
  onInit: event "rfw_loaded" {
    source: "horizontal_product_slider",
    apiCallType: "rest",
    requestUrl: "https://mocki.io/v1/7a6e16f8-9f50-486a-811b-96f3b84bcf07"
  },

  child: Stack(
    children: [

      // CONTENT
      ShowIfEqString(
        left: data.apiResponse.status,
        right: "success",
        child: Column(
          mainAxisSize: "min",
          crossAxisAlignment: "stretch",
          children: [
            Padding(
              padding: [12.0, 8.0, 12.0, 0.0],
              child: Row(
                mainAxisSize: "min",
                crossAxisAlignment: "center",
                children: [
                  Expanded(child: Text(text: ["Featured"], textDirection: "ltr")),
                  GestureDetector(
                    onTap: event "see_all" {},
                    child: Text(text: ["See all"], textDirection: "ltr"),
                  ),
                ],
              ),
            ),

            // Height controls the band; viewportFraction makes next card peek
            HorizontalPager(
              height: 300.0,           // or use viewportMinus if needed
              viewportFraction: 0.5,  // 0.8..0.9 for peek
              itemSpacing: 12.0,
              preloadPagesCount: 10,  // enable if you used the preloading variant
              // onPageChanged: event "carousel_page_changed" { index: data.index },
              children: [
                ...for item in data.apiResponse.response:
                  GestureDetector(
                    onTap: event "product_tap" {
                      id: item.id, title: item.title, price: item.price, image: item.image, url: item.url
                    },
                    child: Column(
                      mainAxisSize: "min",
                      crossAxisAlignment: "stretch",
                      children: [
                        AspectRatio(
                          aspectRatio: 1.2,
                          child: Container(
                            decoration: {
                              type: "box",
                              borderRadius: [ { x: 12.0, y: 12.0 } ],
                              image: { source: item.image, fit: "cover" }
                            },
                          ),
                        ),
                        SizedBox(height: 8.0),
                        Padding(
                          padding: [4.0, 0.0, 4.0, 0.0],
                          child: Text(text: [ item.title ], textDirection: "ltr"),
                        ),
                        SizedBox(height: 4.0),
                        Padding(
                          padding: [4.0, 0.0, 4.0, 0.0],
                          child: Text(text: [ item.price ], textDirection: "ltr"),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),

      // LOADING (skeleton)
      ShowWhen(
        when: data.apiResponse.isLoading,
        child: HorizontalPager(
          viewportFraction: 0.82,
          itemSpacing: 12.0,
          children: [
            ...for i in [0,1,2,3,4]:
              Column(
                mainAxisSize: "min",
                crossAxisAlignment: "stretch",
                children: [
                  AspectRatio(
                    aspectRatio: 0.75,
                    child: Container(
                      decoration: {
                        type: "box",
                        borderRadius: [ { x: 12.0, y: 12.0 } ],
                        color: 0xFFEAEAEA
                      },
                    ),
                  ),
                  SizedBox(height: 8.0),
                  Container(
                    height: 12.0,
                    decoration: {
                      type: "box",
                      borderRadius: [ { x: 6.0, y: 6.0 } ],
                      color: 0xFFE0E0E0
                    },
                  ),
                  SizedBox(height: 6.0),
                  Container(
                    height: 12.0,
                    width: 60.0,
                    decoration: {
                      type: "box",
                      borderRadius: [ { x: 6.0, y: 6.0 } ],
                      color: 0xFFE6E6E6
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    ],
  ),
);
''');
