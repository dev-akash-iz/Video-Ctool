import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_ctool/ui/command_form.dart';
import 'package:video_ctool/ui/command_view.dart';
import 'package:video_ctool/ui/custom_file_picker.dart';
import 'package:video_ctool/ui/expandable_hint_container.dart';
import 'package:video_ctool/utils/ffmpeg_wrappers/ffmpeg_kit.dart';
import 'package:video_ctool/utils/ffmpeg_wrappers/ffprobe_kit.dart';
import 'package:video_ctool/utils/ffmpeg_wrappers/return_code.dart';
import 'package:video_ctool/utils/atomic_functions.dart';
import 'package:video_ctool/api/api_layer.dart';
import 'package:video_ctool/utils/ui_constant.dart';
import '../utils/class_entity/actions_builder.dart';
import '../ui/swipe_action_button.dart';

class VideoConverterPage extends StatefulWidget {
  const VideoConverterPage({super.key});

  @override
  State<VideoConverterPage> createState() => _VideoConverterPageState();
}

class _VideoConverterPageState extends State<VideoConverterPage>
    with WidgetsBindingObserver {
  static const platform = MethodChannel('com.devakash/backButtonIntermediate');

  final ScrollController _scrollController = ScrollController();
  String sf = '@f_'; //selected file string
  String fsl = '@s_'; // file save location
  final String ffmpeg = 'ffmpeg'; // ffmpeg string
  final String ext = '@ext_'; // ffmpeg string
  bool _ConversionSessionOngoing = false;
  bool isSwitched = false;
  String? selectedFilePath;
  String conversionCommand = '';
  double progress = 0.0;
  bool isConverting = false;
  String? fullCommand;
  StringBuffer logOutput = StringBuffer();
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
  String _fileExtension = "";
  List<ActionBuilder>? actions = [];
  bool _enableoverrideFile = false;
  static const int maxLogs = 500;
  int logCount = 0;
  double _scrollPositionFile = 0.0;
  double _scrollPositionInfo = 0.0;

  void updateCommandFromApi(
      void Function(List<dynamic>)? sIdeEffectFunction) async {
    List<dynamic> result = await requestCommandList();
    commandFromGlobal_variable = result;
    sIdeEffectFunction?.call(result);
  }

  Future<bool> onBackButtonPressed(MethodCall call) async {
    if (call.method == "handleBackButtonPress") {
      return _ConversionSessionOngoing;
    }
    return false;
  }

  void _saveScrollPosition() {
    if (isSwitched) {
      _scrollPositionFile = _scrollController.position.pixels;
    } else {
      _scrollPositionInfo = _scrollController.position.pixels;
    }
  }

  void _restoreScrollPosition() {
    if (!_scrollController.hasClients) return;

    if (isSwitched) {
      _scrollController.jumpTo(_scrollPositionFile);
    } else {
      _scrollController.jumpTo(_scrollPositionInfo);
    }
  }

  @override
  void initState() {
    super.initState();
    updateCommandFromApi(null);
    actions = [
      ActionBuilder("Select File", Icons.music_video, () {
        showCustomFilePicker(context);
      }),
      ActionBuilder("Upload Command", Icons.file_upload_sharp, () {
        _openAddCommandScreen(isLocalSave: true);
      })
    ];

    platform.setMethodCallHandler(onBackButtonPressed);
    //_loadSettings();
  }

  void _updateCommandInput(String command) {
    _commandTypeInputBox.text = command;
    conversionCommand = command;
  }

  // Call this method whenever new content is added (e.g., in your setState)
  void _scrollToBottom() {
    if (isSwitched) {
      return;
    }
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

  void _openAddCommandScreen({bool isLocalSave = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (childcontext) => CommandFormScreen(
              workingCommand: conversionCommand,
              parentContext: context,
              isLocalSave: isLocalSave)),
    );
  }

  void showCustomFilePicker(BuildContext Parentcontext) async {
    var status = await requestStoragePermission();
    if (status) {
      showDialog(
        context: Parentcontext,
        barrierDismissible: false, // Prevent accidental closing
        builder: (contextPopup) {
          return CustomFilePicker(
              parentPath, setState, contextPopup, getVideoInfo);
        },
      );
    }
  }

  void showCommandGlobalView(BuildContext context) async {
    // var status = await requestStoragePermission();
    // if (status) {
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
    // }
  }

  @override
  void dispose() {
    // Perform cleanup
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<int> getVideoDuration(String filePath) async {
    final session = await FFprobeKit.getMediaInformation(filePath);
    final mediaInfo = session.getMediaInformation();
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
        logOutput.write(
            "File Moving to cache , please WAIT it may take a while based on size of video");
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
      Map<Object?, Object?> format = mp['format'];

      final information = StringBuffer();
      List<int> audioSubtitleCount = [0, 0];

      String nameTry = format["filename"].toString();
      List<String> formateName = nameTry.split("/");
      double fileSize = double.tryParse(format['size'].toString()) ?? 0;
      List<String> extension = formateName.last.split(".");
      _fileExtension = '.${extension.last}';
      information.write('File Name: ${formateName.last}\n');
      information.write('File Size: ${bytesToSizeFormate(fileSize, "")}\n');
      information
          .write('File Duration: ${formatDuration(format["duration"])}\n');

      information.write('\n');
      information.write('[ DATA STREAMS ]\n');
      information.write('\n');

      for (var every in stream) {
        streamsInformationTemplateGenerate(
            stringBuffer: information,
            formateInfo: format,
            mapOfInformation: every,
            countRefrence: audioSubtitleCount,
            totalSize: fileSize);

        // if (every["codec_type"] == "video" || every["codec_type"] == "audio") {
        //   //what type this tells is this video , audio , subtitle
        //   information.write(
        //       ' (${every['codec_type'] == 'video' ? "*" : len++}) ${every['codec_type'].toUpperCase()}\n\n');
        //   //codec
        //   information.write('         Codec : ${every['codec_name']}\n');
        //   information.write('         Codec : ${every['codec_name']}\n');
        //   information.write(
        //       '${every['codec_type'] == 'audio' ? (', Lang ${every['tags']?['language'] ?? "??"}') : ''} ');
        //   information
        //       .write('Size ${formatFileSize(every, format, fileSize)} \n');

        // }
        information.write('\n');
      }
      setState(() {
        isSwitched = true;
        selectedFilePath = filePath;
        _enableoverrideFile = false;
        _isError = false;
        logOutput.clear();
        // logOutput.write(information.toString());
        SelectedFileInfo = information.toString();
      });
    } else {
      setState(() {
        _isError = true;
        logOutput.write(
            "Issue with getting file info\n Renaming file without special character may resolve this issue");
      });
    }
  }

  void startConversion() async {
    if (_ConversionSessionOngoing) return;
    _ConversionSessionOngoing = true;
    bool isFileNotPresent = stringIsEmpty(selectedFilePath);
    bool isCommandNotPresent = stringIsEmpty(conversionCommand);
    var status = await requestStoragePermission();
    if (isFileNotPresent || isCommandNotPresent || !status) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Error", textAlign: TextAlign.center),
          content: Text(
              status
                  ? alertUserOnIssueOnStart(
                      isFileNotPresent, isCommandNotPresent)
                  : "Please grant storage permission to save files in the download folder.",
              textAlign: TextAlign.center),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      _ConversionSessionOngoing = false;
      return;
    }

    Directory? downloadsDir = await getDownloadsDirectory();
    String filterOne = conversionCommand.replaceAll(RegExp(r'\s+'), ' ').trim();
    // List<String> outputname = filterOne.split(" ");
    // String allExceptLast = outputname.length > 1
    //     ? outputname.sublist(0, outputname.length - 1).join(" ")
    //     : '';
    // String lastWord = outputname.isNotEmpty ? outputname.last : '';
    bool isUserAlreadyNotAllowedOverride = filterOne.contains("-n");
    bool isUserAlreadyAllowedOverride = filterOne.contains("-y");

    String filterTwo = filterOne
        .replaceAll(ffmpeg, '')
        .replaceAll(sf, '"$selectedFilePath"')
        .replaceAll(fsl, "/storage/emulated/0/Download/")
        .replaceAll(ext, _fileExtension)
        .replaceAll("-n", "")
        .replaceAll("-y", "");

    String executableCommand = filterTwo;

    if (isUserAlreadyAllowedOverride && isUserAlreadyNotAllowedOverride) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Error", textAlign: TextAlign.center),
          content: const Text(
              "Conflicting flags: Both '-y' (overwrite) and '-n' (no overwrite) are present. Please provide only one.",
              textAlign: TextAlign.center),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      _ConversionSessionOngoing = false;
      return;
    }

    if (!isUserAlreadyAllowedOverride &&
        _enableoverrideFile &&
        !isUserAlreadyNotAllowedOverride) {
      executableCommand = '-y $executableCommand';
    }

    //fmpeg bug in a way - ffmpeg internally use
    // file_overwrite && no_file_overwrite variable per thread not globaly
    //every thread  start with both 0 then if the command contain -y they assign 1 to it
    // now now based on that particlar command ovveride is acceptable
    // now if you run new command and not have -y if you lucky you get the same thread instance to run
    // where already file_overwrite=1 now even though the command not have -y your precious data get overrided

    // const trying = false;

    // if (trying) {
    //   executableCommand = '-n $executableCommand';
    // }

    // if (!trying) {
    //   executableCommand = '-y $executableCommand';
    // }

    // Fetch total duration using FFprobe
    int totalDuration = await getVideoDuration(selectedFilePath!);
    String everyLoopLog = "";

    _saveScrollPosition();
    setState(() {
      isSwitched = false;
      _restoreScrollPosition();
      logOutput.clear();
      fullCommand = executableCommand;
      isConverting = true;
      progress = 0.0;
      _isError = false;
    });
    // Start the FFmpeg session
    FFmpegKit.executeAsync(
      executableCommand,
      (session) async {
        final returnCode = await session.getReturnCode();

        if (ReturnCode.isSuccess(returnCode)) {
          setState(() {
            _enableoverrideFile = false;
            _isError = false;
            isConverting = false;
            _scrollToBottom();
          });
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Success", textAlign: TextAlign.center),
              content: const Text(
                "File saved successfully.",
                textAlign: TextAlign.center,
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close the dialog first
                    _openAddCommandScreen(); // Open the form screen
                  },
                  child: const Text("Upload This Command"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        } else if (ReturnCode.isCancel(returnCode)) {
          setState(() {
            isConverting = false;
            _isError = true;
            _scrollToBottom();
          });
          showDialog(
              context: context,
              builder: (_) => AlertDialog(
                    title: const Text("Cancelled", textAlign: TextAlign.center),
                    content: const Text("File conversion was cancelled.",
                        textAlign: TextAlign.center),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("OK"),
                      ),
                    ],
                  ));
        } else if (everyLoopLog.contains("already exists") ||
            everyLoopLog.contains("Not overwriting - exiting")) {
          setState(() {
            isConverting = false;
            _isError = true;
            _scrollToBottom();
          });
          showDialog(
            context: context,
            builder: (thisContext) => AlertDialog(
              title: const Text("File Exists", textAlign: TextAlign.center),
              content: const Text(
                  "This file already exists. Enable overwrite? Press 'Start' again to begin conversion.",
                  textAlign: TextAlign.center),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _enableoverrideFile = true; // Enable overwrite
                    });
                    Navigator.pop(context);
                  },
                  child: const Text("Overwrite"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context), // Cancel
                  child: const Text("Cancel"),
                ),
              ],
            ),
          );
        } else {
          setState(() {
            isConverting = false;
            _isError = true;
            _scrollToBottom();
          });
          showDialog(
              context: context,
              builder: (thisContext) => AlertDialog(
                    title: const Text("Error", textAlign: TextAlign.center),
                    content: const Text(
                        "Conversion failed. Please check your command.",
                        textAlign: TextAlign.center),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(thisContext),
                        child: const Text("OK"),
                      ),
                    ],
                  ));
        }
        _ConversionSessionOngoing = false;
      },
      (log) {
        setState(() {
          if (logCount >= maxLogs) {
            logOutput.clear();
            logCount = 0;
          }

          everyLoopLog = log.getMessage();
          logOutput.write('${log.getMessage()}\n\n');
          logCount++;

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
                      icon: const Icon(Icons.notes),
                      label: const Text("Command Center"),
                    ),
                  ),
                  const SizedBox(width: 8), // Adds spacing between buttons
                  Expanded(
                    child: SwipeButton(
                      actions: actions,
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
                style: const TextStyle(
                  fontFamily: "monospace", // Better for coding
                  fontWeight: FontWeight.w500, // Medium weight for clarity
                  height: 1.8, // Balanced line height for better spacing
                  fontSize: 15, // Standard size for command input
                  letterSpacing: 0.5, // Slight spacing for readability
                  color: Colors.black87, // Dark text for white background
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white, // White background
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(5), // Slightly rounded corners
                    borderSide: const BorderSide(
                        color: Colors.blueGrey), // Subtle contrast
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(
                        color: Colors.blueGrey), // Consistent styling
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: Colors.blue.shade400,
                        width: 2), // Emphasize focus
                  ),
                  hintText: "Enter FFmpeg command...",
                  hintStyle: const TextStyle(
                    color: Colors.grey, // Subtle hint text
                    fontFamily: "JetBrainsMono",
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                ),
                cursorColor: Colors.blue, // Blue cursor for visibility
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
                          icon: Icon(isConverting
                              ? Icons.close_rounded
                              : Icons.play_circle),
                          label: Text(isConverting ? "Cancel" : "Start"),
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
                                _saveScrollPosition();
                                setState(() {
                                  isSwitched = value;
                                  _restoreScrollPosition();
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
                      color: _isError
                          ? const Color(0xFFD32F2F)
                          : Colors.blue.shade700,
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
                      height: 220,
                      // Adjust the height as needed
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        scrollDirection: Axis.vertical,
                        child: SelectableText(
                          isSwitched ? SelectedFileInfo : logOutput.toString(),
                          style: TextStyle(
                            fontFamily: "monospace",
                            fontWeight: FontWeight
                                .w500, // Medium weight for balanced emphasis
                            height:
                                1.4, // Slightly more spacing for multi-line readability
                            fontSize: 14, // Optimal for log display
                            letterSpacing: 0.5,
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
