import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rounded_loading_button/rounded_loading_button.dart';
import 'package:tflite/tflite.dart';

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
      title: 'Flutter Demo',
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

  void _capturePic()
  {
    Timer(Duration(seconds: 3), () {
      _btnController.success();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
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
                        if (snapshot.connectionState == ConnectionState.done) {
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
                SizedBox(height: 30,),
                RoundedLoadingButton(
                  color: Colors.orangeAccent,
                  child: Text('Capture Image', style: TextStyle(color: Colors.white)),
                  controller: _btnController,
                  onPressed: () async {
                    // Take the Picture in a try / catch block. If anything goes wrong,
                    // catch the error.
                    try {
                      // Ensure that the camera is initialized.
                      await _initializeControllerFuture;

                      // Construct the path where the image should be saved using the
                      // pattern package.
                      final path = join(
                        // Store the picture in the temp directory.
                        // Find the temp directory using the `path_provider` plugin.
                        (await getTemporaryDirectory()).path,
                        '${DateTime.now()}.png',
                      );

                      // Attempt to take a picture and log where it's been saved.
                      await _controller.takePicture(path);
                      print(path);


                      var recognitions = await Tflite.runModelOnImage(
                          path: File(path).path,
                          numResults: 77,    // defaults to 5
                          threshold: 0.2,
                          imageMean: 0,   // defaults to 117.0
                          imageStd: 0,// defaults to 0.1
                          asynch: true      // required
                      );

                      _btnController.success();

                      Timer(Duration(seconds: 2), () {
                        _btnController.reset();
                      });

//                      Navigator.push(
//                        context,
//                        MaterialPageRoute(
//                          builder: (context) => DisplayPictureScreen(imagePath: path),
//                        ),
//                      );

                      print(recognitions);
                      List<String> l = [];
                      for(final i in recognitions) {
                        l.add(i['label']);
                      }

                      setState(() {
                        labels = l;
                      });

                      // If the picture was taken, display it on a new screen.

                    } catch (e) {
                      // If an error occurs, log the error to the console.
                      print(e);
                    }
                  },
                ),
                SizedBox(height: 20, ),
                Row(
                  children: _createChildren(),
                ),
              ],
            ),
          ],
        ),
      )
    );
  }

  List<Widget> _createChildren() {
    return new List<Widget>.generate(labels.length, (int index) {
      return Wrap(
        children: <Widget>[
          Chip(
            label: Text(labels[index]),
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
      model: "assets/food70B.tflite",
      labels: "assets/labels70B.txt",
    );
  }
}

class DisplayPictureScreen extends StatelessWidget {
  final String imagePath;

  const DisplayPictureScreen({Key key, this.imagePath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Display the Picture')),
      // The image is stored as a file on the device. Use the `Image.file`
      // constructor with the given path to display the image.
      body: Image.file(File(imagePath)),
    );
  }
}
