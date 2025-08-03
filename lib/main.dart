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
      ShowIfEqString(
         left: data.apiResponse.status,
         right: "success", 
        child: SingleChildScrollView(
          scrollDirection: "horizontal",
          child: Row(
            mainAxisSize: "min",
            crossAxisAlignment: "center",
            children: [
              ...for item in data.apiResponse.response:
                Padding(
                  padding: [12.0, 12.0, 0.0, 0.0],
                  child: GestureDetector(
                    onTap: event "item_tap" { title: item.title, url: item.image },
                    child: SizedBox(
                      width: 160.0,
                      child: Column(
                        mainAxisSize: "min",
                        children: [
                          AspectRatio(
                            aspectRatio: 1,
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
                SizedBox(width: 12.0),
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

    ],
  ),
);
''');

  @override
  void initState() {
    super.initState();

    fetchRfwData();
    // 1) Register libraries
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
              'response': <Object>[],
            });

            if (arguments['apiCallType'] == 'rest') {
              final response = await fetchData(arguments['requestUrl'].toString());

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

   fetchRfwData() async {
    final url = Uri.parse("https://res.cloudinary.com/curiozing/raw/upload/v1754219870/grftexample_vziuns.rfw");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = response.bodyBytes;
        _runtime.update(mainName, decodeLibraryBlob(data));
      } else {

      }
    } catch (_) {

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

    'ShowIfEqString': (BuildContext context, DataSource source) {
      final String? left = source.v<String>(const <Object>['left']);
      final String? right = source.v<String>(const <Object>['right']);
      final bool ignoreCase = source.v<bool>(const <Object>['ignoreCase']) ?? false;
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
  });
}

class _ShowIfEqString extends StatelessWidget {
  const _ShowIfEqString({this.left, this.right, this.ignoreCase = false, this.child, this.fallback});
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
    return show ? (child ?? const SizedBox.shrink())
        : (fallback ?? const SizedBox.shrink());
  }
}
