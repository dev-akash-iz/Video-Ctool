import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffprobe_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:video_ctool/api.dart';

void main() async {
  runApp(const MyApp());
}

const List<Widget> hint = [
  Text("• Use @f_ to represent the selected video file (e.g., 'input.mp4')."),
  Text(
      "• Use @s_ to represent the output folder where the converted file will be saved (e.g., '/0/download/')."),
  Text(
      "• In your command, @f_ will automatically be replaced with the selected file's URL."),
  Text(
      "• Similarly, @s_ will be replaced with the download location on your Android device."),
  Text(
      "• This makes your command dynamic and adaptable to different files and locations."),
];

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
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
  Map<String, String> settingsMap = {};
  String? currentPath;
  String parentPath = '/storage/emulated/0/Download';
  List<FileSystemEntity> items = [];
  final TextEditingController _commandTypeInputBox = TextEditingController();
  List<dynamic> commandFromGlobal_variable = [];

  void updateCommandFromApi(
      void Function(List<dynamic>)? sIdeEffectFunction) async {
    List<dynamic> result = await requestCommandList();
    commandFromGlobal_variable = result;
    sIdeEffectFunction?.call(result);
  }

  @override
  void initState() {
    super.initState();
    updateCommandFromApi(null);
    //_loadSettings();
  }

  void _updateCommandInput(String command) {
    _commandTypeInputBox.text = command;
    conversionCommand = command;
  }

  // Call this method whenever new content is added (e.g., in your setState)
  void _scrollToBottom() {
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  // //clearing cashe on app start and on close
  // Future<void> clearCacheOnStart() async {
  //   try {
  //     final directory = await getTemporaryDirectory();
  //     directory.delete(recursive: true);
  //   } catch (e) {
  //     print('Error deleting cache: $e');
  //   }
  // }

  void showCustomFilePicker(BuildContext Parentcontext) async {
    showDialog(
      context: Parentcontext,
      barrierDismissible: false, // Prevent accidental closing
      builder: (contextPopup) {
        return CustomFilePicker(
            parentPath, setState, contextPopup, getVideoInfo);
      },
    );
  }

  void showCommandGlobalView(BuildContext context) async {
    var status = await requestStoragePermission();
    if (status) {
      showDialog(
        context: context,
        barrierDismissible: false, // Prevent accidental closing
        builder: (context) {
          return CommandsGlobal(
              commands: commandFromGlobal_variable,
              loadListFun: updateCommandFromApi,
              inputBoxController: _updateCommandInput);
        },
      );
    }
  }

  @override
  void dispose() {
    // Perform cleanup
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    print('Widget disposed.');
    super.dispose();
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
      var status = await requestStoragePermission();
      if (status) {
        showCustomFilePicker(context);
      }
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
      appBar: AppBar(
        title: const Text(
          "Video Ctool",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue.shade700,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showCommandGlobalView(context);
                      },
                      icon: const Icon(Icons.video_file),
                      label: const Text("Command Center"),
                    ),
                  ),
                  const SizedBox(width: 8), // Adds spacing between buttons
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        selectVideoFile(false, context);
                      },
                      icon: const Icon(Icons.video_file),
                      label: const Text("Select Video File"),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const ExpandableContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: hint,
                ),
              ),
              const SizedBox(height: 10),
              // TextField(
              //   controller: _commandTypeInputBox,
              //   onChanged: (value) => conversionCommand = value,
              //   maxLines: 5,
              //   decoration: const InputDecoration(
              //     border: OutlineInputBorder(),
              //     hintText: "Enter FFmpeg command...",
              //   ),
              // ),
              TextField(
                controller: _commandTypeInputBox,
                onChanged: (value) => conversionCommand = value,
                maxLines: 5,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Enter FFmpeg command...",
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
                      // Start Conversion / Cancel Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              isConverting ? cancelConversion : startConversion,
                          icon: const Icon(Icons.video_file),
                          label: Text(isConverting
                              ? "Cancel Conversion"
                              : "Start Conversion"),
                        ),
                      ),
                      const SizedBox(
                          width: 12), // Adds spacing between elements

                      // Events/File Switch (Ensures Text & Switch stay together)
                      Flexible(
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.end, // Aligns to the right
                          children: [
                            const Text("Event / File"),
                            const SizedBox(width: 2),
                            Switch(
                              value: isSwitched,
                              activeTrackColor: Colors.blue[100],
                              activeColor: Colors.blue,
                              inactiveThumbColor: Colors.green,
                              onChanged: (value) {
                                setState(() {
                                  isSwitched = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                ],
              ), // Red-colored log area
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isError ? Colors.red[50] : Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _isError ? Colors.red : Colors.blue.shade700,
                      width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        isSwitched
                            ? "File Information"
                            : "Current Event Information",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign
                            .center, // Ensures text alignment inside the widget
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Limit the height of the scrollable view
                    SizedBox(
                      height: 200,
                      // Adjust the height as needed
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        scrollDirection: Axis.vertical,
                        child: SelectableText(
                          isSwitched ? SelectedFileInfo : logOutput,
                          style: TextStyle(
                            fontSize: 14,
                            color: _isError
                                ? Colors.red.shade900
                                : Colors.blue.shade900,
                          ),
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
        backgroundColor: Colors.blue.shade700,
        title: Text(
          folderName,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.close,
              color: Colors.white,
            ), // Replace with your desired icon
            onPressed: () {
              widget.closeALL();
            },
          ),
        ],
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
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

//---------------------------------------------------------------------------------------->
class CommandsGlobal extends StatefulWidget {
  final List<dynamic> commands;
  final Function? loadListFun;
  final Function(String) inputBoxController;

  const CommandsGlobal({
    required this.commands,
    required this.loadListFun,
    required this.inputBoxController,
    super.key,
  });

  @override
  State<CommandsGlobal> createState() => _CommandsGlobalState();
}

class _CommandsGlobalState extends State<CommandsGlobal> {
  List<dynamic> commands = [];

  @override
  void initState() {
    super.initState();
    commands = widget.commands;
    widget.loadListFun!((apiResult) {
      if (mounted) {
        setState(() {
          commands = apiResult;
        });
      }
    });
  }

  void _openAddCommandScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CommandFormScreen()),
    );
  }

  void _showCommandDetail(List<dynamic> command, BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommandDetailScreen(
          command: command,
          inputBoxController: widget.inputBoxController,
          parentContext: context,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Command List",
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
        ),
        backgroundColor: Colors.blue.shade700,
        centerTitle: true,
        elevation: 2,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close,
                color: Colors.white), // Replace with your desired icon
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: commands.isEmpty
          ? const Center(
              child: Text(
                "No commands available.",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16.0),
              itemCount: commands.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final command = commands[index];
                return Card(
                  elevation: 4,
                  shadowColor: Colors.blue.shade100,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    title: Text(
                      command[0] ?? "No Title available.",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        (command[2] == null || (command[2] as String) == '')
                            ? "No description available."
                            : command[2],
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black87),
                      ),
                    ),
                    trailing:
                        const Icon(Icons.chevron_right, color: Colors.blue),
                    onTap: () => _showCommandDetail(command, context),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddCommandScreen,
        backgroundColor: Colors.blue.shade700,
        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),
    );
  }
}

//----------------------------------------------------------------------------------------x<

//---------------------------------------------------------------------------------------->

class CommandFormScreen extends StatefulWidget {
  const CommandFormScreen({super.key});

  @override
  State<CommandFormScreen> createState() => _CommandFormScreenState();
}

class _CommandFormScreenState extends State<CommandFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _commandController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _isLoading = false;

  String? _validateField(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "This field cannot be empty.";
    }
    return null;
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      addCommand(
              command: _commandController.text,
              description: _descriptionController.text,
              title: _titleController.text)
          .then((data) {
        print(data);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Command saved!")));
      }).catchError((error) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $error")));
      }).whenComplete(() {
        setState(() {
          _isLoading = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Add Command',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context); // Go back to the previous screen
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField(_titleController, "Command Title"),
                const SizedBox(height: 20),
                _buildTextField(_commandController, "Command", maxLines: 5),
                const SizedBox(height: 20),
                _buildTextField(_descriptionController, "Description",
                    maxLines: 6),
                const SizedBox(height: 30),

                // Submit Button with Loading Indicator
                Center(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 30),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      elevation: 6,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              backgroundColor: Colors.blue,
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "Save Command",
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {int maxLines = 1}) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: label, // Show label text in the center when idle
            hintStyle: const TextStyle(color: Colors.blue),

            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.blue),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          validator: _validateField,
        ),
      ),
    );
  }
}
//----------------------------------------------------------------------------------------x<

//---------------------------------------------------------------------------------------->

class CommandDetailScreen extends StatelessWidget {
  final List<dynamic> command;
  final Function(String) inputBoxController;
  final BuildContext parentContext;
  const CommandDetailScreen(
      {super.key,
      required this.command,
      required this.inputBoxController,
      required this.parentContext});

  void _copyCommand(BuildContext context) {
    // Clipboard.setData(
    //     ClipboardData(text: Uri.decodeComponent(command[1]) ?? ""));
    inputBoxController(Uri.decodeComponent(command[1]));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Command applied!")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background for elegance
      appBar: AppBar(
        title: Text(
          command[0] ?? "",
          style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context); // Go back to the previous screen
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close,
                color: Colors.white), // Replace with your desired icon
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Command Title
              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Command",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SelectableText(
                        command[1] ?? "No command available.",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Command Description
              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Description",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        (command[2] == null || (command[2] as String) == '')
                            ? "No description available."
                            : command[2],
                        style: const TextStyle(
                            fontSize: 16, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Copy Button
              Center(
                child: ElevatedButton.icon(
                  onPressed: () => _copyCommand(context),
                  icon: const Icon(Icons.copy, color: Colors.white),
                  label: const Text(
                    "Use this Command",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 30),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    elevation: 6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExpandableContainer extends StatefulWidget {
  final Widget child;

  const ExpandableContainer({super.key, required this.child});

  @override
  _ExpandableContainerState createState() => _ExpandableContainerState();
}

class _ExpandableContainerState extends State<ExpandableContainer>
    with SingleTickerProviderStateMixin {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              isExpanded = !isExpanded;
            });
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[100], // Background color
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade900),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Show Hints",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.blue.shade800,
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.fastLinearToSlowEaseIn,
          child: isExpanded
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50], // Slightly lighter shade
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: widget.child, // Static text or any content
                )
              : const SizedBox(), // Takes no space when collapsed
        ),
      ],
    );
  }
}
