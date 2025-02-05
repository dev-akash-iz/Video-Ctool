import 'dart:io';

// import 'package:ffmpeg_kit_flutter/media_information.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:clipboard/clipboard.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffprobe_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
// import 'package:ffmpeg_kit_flutter/media_information_session.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as path;

void main() async {
  await Hive.initFlutter();
  await Hive.openBox('settingsBox');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const VideoConverterPage(),
    );
  }
}

class VideoConverterPage extends StatefulWidget {
  const VideoConverterPage({super.key});

  @override
  _VideoConverterPageState createState() => _VideoConverterPageState();
}

Future<bool> requestStoragePermission() async {
  if (Platform.isAndroid) {
    // Get Android version
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    int sdkInt = androidInfo.version.sdkInt; // SDK version as an integer

    if (sdkInt >= 30) {
      // Android 11 (SDK 30) or higher
      if (await Permission.manageExternalStorage.isGranted) {
        print("Manage External Storage permission already granted.");
        return true;
      } else {
        var status = await Permission.manageExternalStorage.request();
        if (status.isGranted) {
          print("Manage External Storage permission granted.");
          return true;
        } else {
          await openAppSettings();
          return false;
        }
      }
    } else {
      // For Android versions lower than 11
      if (await Permission.storage.isGranted) {
        print("Storage permission already granted.");
        return true;
      } else {
        var storageStatus = await Permission.storage.request();
        if (storageStatus.isGranted) {
          print("Storage permission granted.");
          return true;
        } else {
          print("Storage permission denied.");
          return false;
        }
      }
    }
  } else {
    // For non-Android platforms
    print("Storage permission not required on this platform.");
    return true;
  }
}

class _VideoConverterPageState extends State<VideoConverterPage>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  String sf = '@f_'; //selected file string
  String fsl = '@s_'; // file save location

  bool isSwitched = false;
  String? selectedFilePath;
  String conversionCommand = '';
  double progress = 0.0;
  bool isConverting = false;
  String? fullCommand;
  String logOutput = '';
  String SelectedFileInfo = '';
  bool _isError = false;
  String manualPath = '';
  late List<DropdownMenuItem<String>> dropdownItems;
  late Box settingsBox;
  Map<String, String> settingsMap = {};
  String? currentPath;
  String parentPath = '/storage/emulated/0/Download';
  List<FileSystemEntity> items = [];

  @override
  void initState() {
    clearCacheOnStart();
    super.initState();
    //_loadSettings();
  }

  // Call this method whenever new content is added (e.g., in your setState)
  void _scrollToBottom() {
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  String formatFileSize(String bitRateStr, String durationStr) {
    // Convert input strings to numbers
    int bitRate = int.tryParse(bitRateStr) ?? 0;
    double duration = double.tryParse(durationStr) ?? 0.0;

    // Calculate total size in bytes
    double totalBytes = (bitRate * duration) / 8;

    // Convert to KB, MB, GB dynamically
    if (totalBytes >= 1024 * 1024 * 1024) {
      return "${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
    } else if (totalBytes >= 1024 * 1024) {
      return "${(totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB";
    } else if (totalBytes >= 1024) {
      return "${(totalBytes / 1024).toStringAsFixed(2)} KB";
    } else {
      return "${totalBytes.toStringAsFixed(2)} Bytes";
    }
  }

  //clearing cashe on app start and on close
  Future<void> clearCacheOnStart() async {
    try {
      final directory = await getTemporaryDirectory();
      directory.delete(recursive: true);
    } catch (e) {
      print('Error deleting cache: $e');
    }
  }

  void showCustomFilePicker(BuildContext context) async {
    var status = await requestStoragePermission();
    if (status) {
      showDialog(
        context: context,
        barrierDismissible: false, // Prevent accidental closing
        builder: (context) {
          return CustomFilePicker(parentPath, setState, context, getVideoInfo);
        },
      );
    }
  }

  @override
  void dispose() {
    // Perform cleanup
    _scrollController.dispose();
    clearCacheOnStart();
    WidgetsBinding.instance.removeObserver(this);
    print('Widget disposed.');
    super.dispose();
  }

  // Load settings from Hive or set default values
  Future<void> _loadSettings() async {
    settingsBox = Hive.box('settingsBox');

    // Retrieve the stored Map<String, String>, or set default values
    var storedMap = settingsBox
        .get('settingsMap', defaultValue: {'key1': 'value1', 'key2': 'value2'});

    setState(() {
      settingsMap = Map<String, String>.from(storedMap);
      dropdownItems = settingsMap.keys.map((String data) {
        return DropdownMenuItem<String>(
          value: data,
          child: Text(settingsMap[data]!),
        );
      }).toList(); // Make sure it's a Map
    });
  }

  Future<int> getVideoDuration(String filePath) async {
    final session = await FFprobeKit.getMediaInformation(filePath);
    final mediaInfo = session.getMediaInformation();
    Map<dynamic, dynamic>? mp = mediaInfo?.getAllProperties();
    print(mp);
    //Map<dynamic, dynamic>? x = mediaInfo?.getAllProperties();
    //print(x);
    if (mediaInfo != null) {
      final durationStr =
          mediaInfo.getDuration(); // Duration in seconds as a string
      if (durationStr != null) {
        return (double.parse(durationStr) * 1000)
            .toInt(); // Convert to milliseconds
      }
    }
    return 0; // Return 0 if duration cannot be determined
  }

  void selectVideoFile(bool isByfilePicker, BuildContext context) async {
    clearCacheOnStart();
    String? io;
    if (isByfilePicker) {
      setState(() {
        logOutput =
            "File Moving to cache , please WAIT it may take a while based on size of video";
      });
      FilePickerResult? result;
      try {
        result = await FilePicker.platform.pickFiles(
            type: FileType.any, withData: false, withReadStream: false);
        io = result?.files.single.path;
        getVideoInfo(io!);
      } catch (e) {
        print('Error in selecting file');
      }
    } else {
      showCustomFilePicker(context);
    }
  }

  void getVideoInfo(String filePath) async {
    final session = await FFprobeKit.getMediaInformation(filePath);
    final mediaInfo = session.getMediaInformation();
    if (filePath.isNotEmpty && mediaInfo != null) {
      Map<dynamic, dynamic>? mp = mediaInfo.getAllProperties();
      List stream = mp!['streams'];

      final information = StringBuffer();
      int len = 0;
      // Size ${formatFileSize(every['bit_rate'] ?? "0", every['duration'] ?? "0")}
      for (var every in stream) {
        information.write(
            ' (${every['codec_type'] == 'video' ? "*" : len++}) ${every['codec_type']} =>  Codec ${every['codec_name']} ${every['codec_type'] == 'audio' ? (', Lang ${every['tags']?['language'] ?? "??"}') : ''} \n');
      }
      setState(() {
        selectedFilePath = filePath;
        _isError = false;
        logOutput = information.toString();
        SelectedFileInfo = information.toString();
      });
    } else {
      setState(() {
        _isError = true;
        logOutput =
            "Issue with getting file info\n Renaming file without special character may resolve this issue";
      });
    }
  }

  void startConversion() async {
    setState(() {
      _isError = false;
      logOutput = "";
    });
    var status = await requestStoragePermission();
    if (selectedFilePath == null || conversionCommand.isEmpty || !status) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Error"),
          content: Text(status
              ? "Please select a video file and enter a conversion command."
              : "Please provide storage permission, to store data on download"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return;
    }

    Directory? downloadsDir = await getDownloadsDirectory();

    if (downloadsDir == null) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Error"),
          content: const Text("some issue with storage"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return;
    }
    String filterOne = conversionCommand.replaceAll(RegExp(r'\s+'), ' ').trim();
    // List<String> outputname = filterOne.split(" ");
    // String allExceptLast = outputname.length > 1
    //     ? outputname.sublist(0, outputname.length - 1).join(" ")
    //     : '';
    // String lastWord = outputname.isNotEmpty ? outputname.last : '';
    String filterTwo = filterOne
        .replaceFirst(sf, '"$selectedFilePath"')
        .replaceFirst(fsl, "/storage/emulated/0/Download/");

    String executableCommand = '-y $filterTwo';
    setState(() {
      fullCommand = executableCommand;
      isConverting = true;
      progress = 0.0;
      _isError = false;
    });

    // Fetch total duration using FFprobe
    int totalDuration = await getVideoDuration(selectedFilePath!);

    // Start the FFmpeg session
    await FFmpegKit.executeAsync(
      executableCommand,
      (session) async {
        final returnCode = await session.getReturnCode();
        setState(() {
          isConverting = false;
        });

        if (ReturnCode.isSuccess(returnCode)) {
          setState(() {
            _isError = false;
          });
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Success"),
              content: const Text("Video converted successfully! Saved"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
          clearCacheOnStart();
        } else if (ReturnCode.isCancel(returnCode)) {
          setState(() {
            _isError = true;
          });
          showDialog(
              context: context,
              builder: (_) => AlertDialog(
                    title: const Text("Cancelled"),
                    content: const Text("Video conversion was cancelled."),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("OK"),
                      ),
                    ],
                  ));
        } else {
          setState(() {
            _isError = true;
          });
          showDialog(
              context: context,
              builder: (_) => AlertDialog(
                    title: const Text("Error"),
                    content: const Text(
                        "Conversion failed. Please check your command."),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("OK"),
                      ),
                    ],
                  ));
        }
      },
      (log) {
        setState(() {
          logOutput += '${log.getMessage()} \n';
          _scrollToBottom();
        });
      }, // Logs the FFmpeg process
      (statistics) {
        setState(() {
          if (totalDuration > 0) {
            progress = (statistics.getTime() / totalDuration) * 100;
          }
        });
      },
    );
  }

  void cancelConversion() {
    FFmpegKit.cancel();
    setState(() {
      isConverting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Video Ctool")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "1. Select a video file:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceEvenly, // Ensures spacing
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        selectVideoFile(true, context);
                      },
                      child: const Text("Default File Picker"),
                    ),
                  ),
                  const SizedBox(width: 8), // Space between buttons
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        selectVideoFile(false, context);
                      },
                      child: const Text("Custom File Picker"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              selectedFilePath != null
                  ? Row(
                      children: [
                        Text(
                          '$sf > selected file url: ',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Expanded(
                            child: SingleChildScrollView(
                          child: Text(
                            selectedFilePath!,
                            overflow: TextOverflow
                                .ellipsis, // Adds ellipsis if content is truncated
                            maxLines: 1, // Show only 3 lines by default
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[700]),
                          ),
                        )),
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () {
                            FlutterClipboard.copy(selectedFilePath!).then((_) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text("File path copied to clipboard!")),
                              );
                            });
                          },
                        ),
                      ],
                    )
                  : Text('$sf > selected file url: No file selected.',
                      style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              fullCommand != null
                  ? Row(
                      children: [
                        Text(
                          '$fsl > final command: ',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Expanded(
                            child: SingleChildScrollView(
                          child: Text(
                            fullCommand!,
                            overflow: TextOverflow
                                .ellipsis, // Adds ellipsis if content is truncated
                            maxLines: 1, // Show only 3 lines by default
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[700]),
                          ),
                        )),
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () {
                            FlutterClipboard.copy(fullCommand!).then((_) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text("File path copied to clipboard!")),
                              );
                            });
                          },
                        ),
                      ],
                    )
                  : Text('$fsl > final command:  No fullCommand calculated.',
                      style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 10),
              const Text(
                "2. Enter your FFmpeg command:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) => conversionCommand = value,
                maxLines: 5,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText:
                      "# @f_ = Input file (like 'input.mp4')\n# @s_ = Output location (like '/0/download/'')\n# Example: -i @f_ -vcodec libx265 -crf 30 -preset slow -acodec aac -b:a 96k @s_/output.mp4",
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Progress Bar & Status
                  if (isConverting)
                    Column(
                      children: [
                        LinearProgressIndicator(value: progress / 100),
                        const SizedBox(height: 8),
                        Text("Progress: ${progress.toStringAsFixed(2)}%"),
                      ],
                    ),

                  const SizedBox(height: 8),

                  // Buttons & Switch in a Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed:
                            isConverting ? cancelConversion : startConversion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isConverting
                              ? Colors.red
                              : const Color.fromARGB(255, 184, 170, 166),
                        ),
                        child: Text(isConverting
                            ? "Cancel Conversion"
                            : "Start Conversion"),
                      ),
                      Row(
                        children: [
                          const Text("event info / file info",
                              style: TextStyle(fontSize: 14)),
                          Switch(
                            value:
                                isSwitched, // Define this in State: bool isSwitched = false;
                            onChanged: (value) {
                              setState(() {
                                isSwitched = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                ],
              ), // Red-colored log area
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _isError ? Colors.red : Colors.green, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Log Output:",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    // Limit the height of the scrollable view
                    SizedBox(
                      height: 200, // Adjust the height as needed
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        scrollDirection: Axis.vertical,
                        child: SelectableText(
                          isSwitched ? SelectedFileInfo : logOutput,
                          style: TextStyle(
                              fontSize: 14,
                              color: _isError ? Colors.red : Colors.green),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomFilePicker extends StatefulWidget {
  final String initialPath;
  final Function updateParentMain;
  final BuildContext contextParent;
  final Function updateVideoDetail;

  void closeALL() {
    Navigator.pop(contextParent);
  }

  const CustomFilePicker(this.initialPath, this.updateParentMain,
      this.contextParent, this.updateVideoDetail,
      {super.key});

  @override
  _CustomFilePickerState createState() => _CustomFilePickerState();
}

class _CustomFilePickerState extends State<CustomFilePicker> {
  final String topMostDirectory = '/storage/emulated/0';
  late String currentPath;
  Directory? currentdir;
  List<FileSystemEntity> items = [];
  bool filterFileExtension = false;
  Map<String, bool> listExtension = {
    // Video extensions
    ".mp4": true,
    ".mkv": true,
    ".mov": true,
    ".avi": true,
    // ".wmv": true,
    // ".flv": true,
    // ".webm": true,
    // ".mpeg": true,
    // ".mpg": true,
    // ".3gp": true,
    // ".m4v": true,
    // ".ts": true,

    // Audio extensions
    // ".mp3": true,
    // ".wav": true,
    // ".aac": true,
    // ".flac": true,
    // ".ogg": true,
    // ".wma": true,
    // ".m4a": true,
    // ".opus": true,
    // ".alac": true,
    // ".aiff": true,
    // ".amr": true,
  };

  @override
  void initState() {
    super.initState();
    currentPath = widget.initialPath;
    currentdir = Directory(currentPath);
    _loadFiles();
  }

  void _backNavigate() {
    if (topMostDirectory == currentPath) {
      widget.closeALL();
    } else {
      currentdir = Directory(path.dirname(currentPath));
      currentPath = currentdir!.path;
      setState(() {
        _loadFiles();
      });
    }
  }

  void _loadFiles() {
    if (currentdir!.existsSync()) {
      setState(() {
        items = currentdir!.listSync();
      });
    }
  }

  void _navigateToFolder(String path) {
    currentdir = Directory(path);
    setState(() {
      currentPath = path;
      _loadFiles();
    });
  }

  void _selectFile(String filePath) {
    String fileExtension =
        filePath.substring(filePath.lastIndexOf("."), filePath.length);
    if (listExtension[fileExtension] == true) {
      print(filePath);
      widget.updateVideoDetail(filePath);
      _convertVideo(filePath);
    } else {
      _showErrorDialog("Please select a valid video file.");
    }
  }

  void _convertVideo(String filePath) {
    print("Converting video: $filePath");
    widget.closeALL();
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String folderName = path.basename(currentPath);
    return Scaffold(
      appBar: AppBar(
        title: Text(folderName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _backNavigate();
          }, // Close dialog
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                FileSystemEntity entity = items[index];
                bool isDir = FileSystemEntity.isDirectorySync(entity.path);
                String fileExtension;
                if (filterFileExtension &&
                    !isDir &&
                    (fileExtension = entity.path.substring(
                            entity.path.lastIndexOf("."), entity.path.length))
                        .isNotEmpty &&
                    listExtension[fileExtension] == null) {
                  return const SizedBox.shrink();
                }

                return ListTile(
                  leading: Icon(isDir ? Icons.folder : Icons.video_file),
                  title: Text(entity.path.split('/').last),
                  onTap: () {
                    if (isDir) {
                      _navigateToFolder(entity.path);
                    } else {
                      _selectFile(entity.path);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
