import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home'),
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
  static const platform = MethodChannel('com.theamorn.flutter');

  @override
  void initState() {
    super.initState();
    _receiveDataFromNative();
  }

  int _counter = 0;
  String dataFromNative = "";

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  Future<void> _receiveDataFromNative() async {
    try {
      // Listening for data passed from the native side
      platform.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'passValueFromNative':
            final data = call.arguments as String;
            setState(() {
              dataFromNative = data;
            });
            break;
          default:
            break;
        }
      });
    } on PlatformException catch (e) {
      setState(() {
        dataFromNative = "Failed to receive data: '${e.message}'";
      });
    }
  }

  Future<void> _sendDataToNative(int value) async {
    try {
      await platform.invokeMethod('getValueFromFlutter', value);
    } catch (e) {
      print("Failed to get value: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            TextButton(
                onPressed: () {
                  print("Button pressed and send data to native: $_counter");
                  _sendDataToNative(_counter);
                },
                child: const Text("Submit")),
            Text('Data: $dataFromNative',
                style: Theme.of(context).textTheme.headlineMedium)
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}