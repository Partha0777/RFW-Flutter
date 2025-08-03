import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
  static const LibraryName appName  = LibraryName(<String>['app']);   // your local lib name
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
          if(asyncSnapshot.data != null){
            _runtime.update(mainName,asyncSnapshot.data as WidgetLibrary);
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
            );
          }else{
            return SizedBox();
          }
        }
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
    final hListExample = Uri.parse("https://res.cloudinary.com/curiozing/raw/upload/v1754219870/grftexample_vziuns.rfw");
    final vListExample = Uri.parse("https://res.cloudinary.com/curiozing/raw/upload/v1754234779/grftexample1_pq2opf.rfw");
    final vPageExample = Uri.parse("https://res.cloudinary.com/curiozing/raw/upload/v1754237037/grftexample2_xxsgdw.rfw");

    try {
      final response = await http.get(vPageExample);
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
          final double effectiveHeight =
          baseHeight.clamp(0.0, constraints.maxHeight);

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
