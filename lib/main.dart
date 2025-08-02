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
      title: 'Flutter Demo',
      theme: ThemeData(

        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
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
  static const LibraryName appName  = LibraryName(<String>['app']);   // your local lib name
  static const LibraryName mainName = LibraryName(<String>['main']);

  // ────────────────────────────────────────────────────────────────────────────
  // Remote UI
  // ────────────────────────────────────────────────────────────────────────────
  static final RemoteWidgetLibrary _remoteWidgets = parseLibraryFile(r'''
import core.widgets;
import app;  // exposes OnInit + ShowWhen + Loader

// Horizontal cards with loader, empty, and error states
widget root = OnInit(
  onInit: event "rfw_loaded" {
    source: "horizontal_list",
    apiCallType: "rest",
    requestUrl : "https://mocki.io/v1/eb7be3f6-d425-4444-8534-26e52ed88512"
  },

  child: Stack(
    children: [

      // ── CONTENT (only when we have data)
      ShowWhen(
        when: data.apiResponse.hasData,
        child: SingleChildScrollView(
          scrollDirection: "horizontal",
          child: Row(
            mainAxisSize: "min",
            crossAxisAlignment: "center",
            children: [
              ...for item in data.apiResponse.response:
                Padding(
                  padding: [0.0, 0.0, 12.0, 0.0],
                  child: GestureDetector(
                    onTap: event "item_tap" { title: item.title, url: item.image },
                    child: SizedBox(
                      width: 160.0,
                      child: Column(
                        mainAxisSize: "min",
                        children: [
                          AspectRatio(
                            aspectRatio: 1.7777778,
                            child: Container(
                              decoration: {
                                type: "box",
                                borderRadius: [ { x: 12.0, y: 12.0 } ],
                                image: { source: item.image, fit: "cover" }
                              },
                            ),
                          ),
                          SizedBox(height: 6.0),
                          Padding(
                            padding: [4.0, 0.0, 4.0, 0.0],
                            child: Text(text: [ item.title ], textDirection: "ltr"),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),

      // ── LOADING: skeleton row (left/right scrollable)
      ShowWhen(
        when: data.apiResponse.isLoading,
        child: SingleChildScrollView(
          scrollDirection: "horizontal",
          child: Row(
            mainAxisSize: "min",
            crossAxisAlignment: "center",
            children: [
              // 6 placeholder cards
              ...for i in [0,1,2,3,4,5]:
                Padding(
                  padding: [0.0, 0.0, 12.0, 0.0],
                  child: SizedBox(
                    width: 160.0,
                    child: Column(
                      mainAxisSize: "min",
                      children: [
                        AspectRatio(
                          aspectRatio: 1.7777778,
                          child: Container(
                            decoration: {
                              type: "box",
                              borderRadius: [ { x: 12.0, y: 12.0 } ],
                              color: 0xFFEAEAEA
                            },
                          ),
                        ),
                        SizedBox(height: 6.0),
                        Container(
                          height: 12.0,
                          decoration: {
                            type: "box",
                            borderRadius: [ { x: 6.0, y: 6.0 } ],
                            color: 0xFFE0E0E0
                          },
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),

      // ── LOADING: small spinner overlay (on top of skeletons)
      ShowWhen(
        when: data.apiResponse.isLoading,
        child: Center(
          child: Loader(strokeWidth: 2.0),
        ),
      ),

      // ── EMPTY: loaded but nothing to show
      ShowWhen(
        when: data.apiResponse.isEmpty,
        child: Center(
          child: Padding(
            padding: [12.0, 12.0, 12.0, 12.0],
            child: Text(text: ["No items found"], textDirection: "ltr"),
          ),
        ),
      ),

      // ── ERROR: show message + retry button
      ShowWhen(
        when: data.apiResponse.isError,
        child: Center(
          child: Column(
            mainAxisSize: "min",
            children: [
              Padding(
                padding: [12.0, 0.0, 12.0, 8.0],
                child: Text(text: ["Couldn't load items"], textDirection: "ltr"),
              ),
              GestureDetector(
                onTap: event "rfw_loaded" {
                  source: "horizontal_list",
                  apiCallType: "rest",
                  requestUrl : "https://mocki.io/v1/eb7be3f6-d425-4444-8534-26e52ed88512"
                },
                child: Container(
                  padding: [12.0, 8.0, 12.0, 8.0],
                  decoration: {
                    type: "box",
                    borderRadius: [ { x: 8.0, y: 8.0 } ],
                    color: 0xFFEEEEEE
                  },
                  child: Text(text: ["Retry"], textDirection: "ltr"),
                ),
              ),
            ],
          ),
        ),
      ),

    ],
  ),
);
''');

  @override
  void initState() {
    super.initState();

    // 1) Register libraries
    _runtime
      ..update(coreName, createCoreWidgets())
      ..update(appName, createAppWidgets())
      ..update(mainName, _remoteWidgets);

    // 2) Initial content with loader visible
    _data = DynamicContent(<String, Object>{
      'apiResponse': <String, Object>{
        'status': 'idle',
        'isLoading': true,
        'hasData': false,
        'isEmpty': false,
        'isError': false,
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
      body: RemoteWidget(
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
            if (_isFetching) return; // ignore while an earlier fetch is running
            _isFetching = true;

            // Show loader immediately
            _data.update('apiResponse', <String, Object>{
              'status': 'loading',
              'isLoading': true,
              'hasData': false,
              'isEmpty': false,
              'isError': false,
              'response': <Object>[],
            });

            if (arguments['apiCallType'] == 'rest') {
              final response = await fetchData(arguments['requestUrl'].toString());

              if (response['status'] == 'success') {
                final dynamic body = response['response'];
                final List<Object> list =
                body is List ? List<Object>.from(body) : <Object>[];

                _data.update('apiResponse', <String, Object>{
                  'status': 'success',
                  'isLoading': false,
                  'hasData': true,
                  'isEmpty': false,
                  'isError': false,
                  'response': body,
                });
              } else {
                _data.update('apiResponse', <String, Object>{
                  'status': 'failure',
                  'isLoading': false,
                  'hasData': false,
                  'isEmpty': false,
                  'isError': true,
                  'response': <Object>[],
                });
              }
            }

            _isFetching = false;
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
  Widget build(BuildContext context) =>
      show ? (child ?? const SizedBox.shrink()) : (fallback ?? const SizedBox.shrink());
}

// Simple loader using Material’s CircularProgressIndicator locally.
class _Loader extends StatelessWidget {
  const _Loader({this.strokeWidth});
  final double? strokeWidth;
  @override
  Widget build(BuildContext context) =>
      CircularProgressIndicator(strokeWidth: strokeWidth ?? 4.0);
}

LocalWidgetLibrary createAppWidgets() {
  return LocalWidgetLibrary(<String, LocalWidgetBuilder>{
    'OnInit': (BuildContext context, DataSource source) {
      final child = source.optionalChild(const <Object>['child']) ?? const SizedBox.shrink();
      final onInit = source.voidHandler(const <Object>['onInit']);
      return _OnInit(onInit: onInit, child: child);
    },

    // ShowWhen: reads `when:` (preferred) or `show:` for backward-compat
    'ShowWhen': (BuildContext context, DataSource source) {
      final bool show = (source.v<bool>(const <Object>['when'])
          ?? source.v<bool>(const <Object>['show'])
          ?? false);
      final Widget? child = source.optionalChild(const <Object>['child']);
      final Widget? fallback = source.optionalChild(const <Object>['fallback']);
      return _ShowWhen(show: show, child: child, fallback: fallback);
    },

    // Local loader so remote code doesn't need `core.material`
    'Loader': (BuildContext context, DataSource source) {
      final double? width = source.v<double>(const <Object>['strokeWidth']);
      return _Loader(strokeWidth: width);
    },
  });
}
