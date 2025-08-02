import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rfw/formats.dart';
import 'package:rfw/rfw.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
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
  DynamicContent _data = DynamicContent();

  static final RemoteWidgetLibrary _remoteWidgets = parseLibraryFile(r'''
import core.widgets;
import app;  // <-- your local library name

widget root = OnInit(
  onInit: event "rfw_loaded" {
  source: "horizontal_list", 
  apiCallType: "rest", 
  requestUrl : "https://mocki.io/v1/eb7be3f6-d425-4444-8534-26e52ed88512"
  },
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
              onTap: event "item_tap" { title: item.title, url: item.image},
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
);
''');





  static const LibraryName coreName = LibraryName(<String>['core', 'widgets']);
  static const LibraryName appName  = LibraryName(<String>['app']); // your local lib name
  static const LibraryName mainName = LibraryName(<String>['main']);

  @override
  void initState() {
    super.initState();
    // Local widget library:
    _runtime.update(coreName, createCoreWidgets());
    _runtime.update(appName, createAppWidgets());
    // Remote widget library:
    _runtime.update(mainName, _remoteWidgets);

    // Configuration data:
    //_data.update('greet', <String, Object>{'name': 'World'});


  }

  @override
  Widget build(BuildContext context) {

    _data = DynamicContent({
      'apiResponse': <String, Object>{}
    });

    bool _sentLoaded = false;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: RemoteWidget(
        runtime: _runtime,
        data: _data,
        widget: const FullyQualifiedWidgetName(mainName, 'root'),
        onEvent: (String name, DynamicMap arguments) async{
          if (name == 'item_tap') {
            final who = (arguments['title'] ?? 'there').toString();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Hi $who 👋'),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          }else if (name == 'rfw_loaded' && !_sentLoaded) {
            if(arguments["apiCallType"] == "rest"){
               final response = await fetchData(arguments["requestUrl"].toString());
               _data.update('apiResponse',response);
            }
            _sentLoaded = true;
          }
        },
      ),

    );
  }


  Future<Map<String,dynamic>> fetchData(String requestURL) async {
    final url = Uri.parse(requestURL);
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {"status": "success", "response" : data};
      } else {
        return {"status": "failure"};
      }
    } catch (e) {
      return {"status": "failure"};
    }
  }
}

LocalWidgetLibrary createAppWidgets() {
  return LocalWidgetLibrary(<String, LocalWidgetBuilder>{
    'OnInit': (BuildContext context, DataSource source) {
      final child = source.child(const <Object>['child']);
      final onInit = source.voidHandler(const <Object>['onInit']); // fetch event handler from rfwtxt
      return _OnInit(onInit: onInit, child: child);
    },
  });
}


// 1) A stateful widget that triggers a callback once after the first frame.
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

