import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart'; // To generate unique IDs
import 'package:flutter/services.dart'; // To use Clipboard
import 'package:qr_flutter/qr_flutter.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'URL Validator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: UrlValidatorScreen(),
    );
  }
}

class UrlValidatorScreen extends StatefulWidget {
  @override
  _UrlValidatorScreenState createState() => _UrlValidatorScreenState();
}

class _UrlValidatorScreenState extends State<UrlValidatorScreen> {
  List<ContainerData> _containers = [];
  String data = "http://example.com"; // Initial URL
  String ip="127.0.0.1";

  final Dio _dio = Dio();

  // Method to validate the URL for a specific container
  Future<void> _validateUrl(String containerId) async {
    ContainerData container = _containers.firstWhere((container) => container.id == containerId);

    String url = container.controller.text;
    if (url.isEmpty) {
      setState(() {
        container.validationMessage = 'Please enter a URL';
        container.isValid = false;
      });
      return;
    }

    final isValidFormat = Uri.tryParse(url)?.hasScheme ?? false;
    if (!isValidFormat) {
      setState(() {
        container.validationMessage = 'Invalid URL format';
        container.isValid = false;
      });
      return;
    }

    var data = {
      'user_id': 'user1',
      'session_id': containerId,
      'url': url,
    };

    try {
      final response = await _dio.post("http://${ip}:5000/create_tunnel", data: data);
      if (response.statusCode == 200) {
        setState(() {
          container.validationMessage = '${response.data["tunnel_url"]}';
          this.data = response.data["tunnel_url"];
          container.isValid = true;
        });
      } else {
        setState(() {
          container.validationMessage = 'URL is not accessible (Status: ${response.statusCode})';
          container.isValid = false;
        });
      }
    } on DioError catch (e) {
      if (e.type == DioErrorType.badResponse) {
        setState(() {
          container.validationMessage = 'Failed to connect to the server.';
          container.isValid = false;
        });
      } else {
        setState(() {
          container.validationMessage = 'Error: ${e.message}';
          container.isValid = false;
        });
      }
    }
  }

  // Method to stop the server
  Future<void> destory_server(String containerId) async {
    try {
      final response = await _dio.post("http://${ip}:5000/destroy_tunnel", data: {'user_id': 'user1','session_id': containerId,});

      if (response.statusCode == 200) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Info'),
              content: Text('Tunneling Stopped'),
              actions: <Widget>[
                TextButton(
                  child: Text('Close', style: TextStyle(color: Colors.red)),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }
    } on DioError catch (e) {
      print("Error destroying container: ${e}");
    }
  }

  // Method to add a new container with its own TextEditingController and ID
  void _addNewContainer() {
    setState(() {
      String containerId = Uuid().v4(); // Generate a unique ID for the container
      _containers.add(ContainerData(
        id: containerId,
        controller: TextEditingController(),
        validationMessage: '',
        isValid: false,
      ));
    });
  }

  // Method to remove a container
  void _removeContainer (String containerId) async{

    //await destory_server(containerId);
    setState(() {
      _containers.removeWhere((container) => container.id == containerId);
    });

  }

  // Method to copy the URL to clipboard
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('URL copied to clipboard!')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('HOSTER'),
        centerTitle: true,
        backgroundColor: Colors.blueGrey,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: _containers.map((container) {
              return Container(
                margin: EdgeInsets.symmetric(vertical: 8),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      offset: Offset(0, 4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Close button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.red),
                          onPressed: () {
                            _removeContainer(container.id);
                          },
                        ),
                      ],
                    ),
                    QrImageView(
                      data: data,
                      version: QrVersions.auto,
                      size: 200.0,
                      gapless: false,
                    ),
                    SizedBox(height: 16),
                    Text(
                      container.validationMessage,
                      style: TextStyle(
                        color: container.isValid ? const Color.fromARGB(255, 9, 92, 12) : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (container.isValid)
                      GestureDetector(
                        onTap: () => _copyToClipboard(container.validationMessage),
                        child: Text(
                          "COPY",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    SizedBox(height: 10),
                    TextField(
                      controller: container.controller,
                      decoration: InputDecoration(
                        labelText: 'Enter URL',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            _validateUrl(container.id);
                          },
                          child: Text('Start Server'),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            destory_server(container.id);
                          },
                          child: Text('Stop Server'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewContainer,
        child: Icon(Icons.add),
        tooltip: 'Add New URL Validator',
      ),
    );
  }
}

// Container data model
class ContainerData {
  final String id; // Unique ID for the container
  final TextEditingController controller; // TextEditingController for this container
  String validationMessage; // Validation message for the container
  bool isValid; // Validity status for the URL in this container

  ContainerData({
    required this.id,
    required this.controller,
    required this.validationMessage,
    required this.isValid,
  });
}
