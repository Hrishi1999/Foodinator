import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rounded_loading_button/rounded_loading_button.dart';
import 'package:tflite/tflite.dart';
import 'package:image/image.dart' as img;

var firstCam;

Future<void> main() async {
  // Ensure that plugin services are initialized so that `availableCameras()`
  // can be called before `runApp()`
  WidgetsFlutterBinding.ensureInitialized();

  // Obtain a list of the available cameras on the device.
  final cameras = await availableCameras();

  // Get a specific camera from the list of available cameras.
  firstCam = cameras.first;

  runApp(MyApp());
}

class MyApp extends StatelessWidget {

  // This widget is the root of your application.

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: Colors.orange,
    ));
    return MaterialApp(
      title: 'Foodinator',
      theme: ThemeData(
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Foodinator', camera: firstCam),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title, this.camera}) : super(key: key);

  final CameraDescription camera;
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  CameraController _controller;
  Future<void> _initializeControllerFuture;
  var modelLoaded = false;
  List<String> labels = [];
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    // To display the current output from the camera,
    // create a CameraController.
    _controller = CameraController(
      // Get a specific camera from the list of available cameras.
      widget.camera,
      // Define the resolution to use.
      ResolutionPreset.medium,
    );

    TFLiteHelper.loadModel().then((value) {
      setState(() {
        modelLoaded = true;
      });
    });

    // Next, initialize the controller. This returns a Future.
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appLifecycleState) {
    if (appLifecycleState == AppLifecycleState.resumed) {
      _controller != null
          ? _initializeControllerFuture = _controller.initialize()
          : null;
    }
  }

  final RoundedLoadingButtonController _btnController = new RoundedLoadingButtonController();

  @override
  Widget build(BuildContext context) {
      return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.orange,
        title: Text(widget.title),
      ),
      body: Container(
        padding: const EdgeInsets.all(15.0),
        child: Wrap(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8.0),
                topRight: Radius.circular(8.0),
                bottomRight: Radius.circular(8.0),
                bottomLeft: Radius.circular(8.0),
              ),
              child: Container(
                  width: 400,
                  height: 400,
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: FutureBuilder<void>(
                      future: _initializeControllerFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done && _controller.value.isInitialized) {
                          // If the Future is complete, display the preview.
                          return CameraPreview(_controller);
                        } else {
                          // Otherwise, display a loading indicator.
                          return Center(child: CircularProgressIndicator());
                        }
                      },
                    ),
                  )
              ),
            ),
            SizedBox(width: 85, height: 10,),
            Wrap(
              direction: Axis.horizontal,
              spacing: 15,
              children: <Widget>[
                SizedBox(height: 10,),
                RoundedLoadingButton(
                  color: Colors.orangeAccent,
                  child: Text('Capture Image', style: TextStyle(color: Colors.white)),
                  controller: _btnController,
                  onPressed: () async {

                    setState(() {
                      _visible = false;
                    });

                    try {
                      await _initializeControllerFuture;

                      final path = join(

                        (await getTemporaryDirectory()).path,
                        '${DateTime.now()}.png',
                      );

                      await _controller.takePicture(path);
                      print(path);


                      var recognitions = await Tflite.runModelOnImage(
                          path: File(path).path,
                          numResults: 45,    // defaults to 5
                          threshold: 0.1,
                          imageMean: 0,   // defaults to 117.0
                          imageStd: 255,// defaults to 0.1
                          asynch: true      // required
                      );

                      _btnController.success();

                      setState(() {
                        _visible = true;
                      });

                      Timer(Duration(milliseconds: 1500), () {
                        _btnController.reset();
                      });

                      print(recognitions);
                      List<String> l = [];
                      for(final i in recognitions) {
                        l.add(i['label']);
                      }

                      setState(() {
                        labels = l;
                      });


                    } catch (e) {
                      print(e);
                    }
                  },
                ),
                SizedBox(height: 20, ),
                AnimatedOpacity(
                  opacity: _visible ? 1.0 : 0.0,
                  duration: Duration(milliseconds: 500),
                  child: Wrap(
                    children:_createChildren(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      )
    );
  }

  List<Widget> _createChildren(BuildContext context) {
    return new List<Widget>.generate(labels.length, (int index) {
      return Wrap(
        children: <Widget>[
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DisplayDish(dish: labels[index]),
                ),
              );
            },
            child: Chip(
              label: Text(labels[index]),
            ),
          ),
          SizedBox(width: 10,)
        ],
      );
    });
  }

}

class TFLiteHelper {
  static Future<String> loadModel() async {
    return Tflite.loadModel(
      model: "assets/model9763.tflite",
      labels: "assets/labels9763.txt",
    );
  }
}

class DisplayDish extends StatefulWidget {
  final String dish;

  const DisplayDish({Key key, this.dish}) : super(key: key);

  @override
  _DisplayDish createState() => _DisplayDish();
}

class _DisplayDish extends State<DisplayDish> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.orange,
        title: Text(widget.dish),
    ),
    body: Text('asd'),
    );
  }
}
