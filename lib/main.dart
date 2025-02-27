import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:video_ctool/api.dart';
import 'package:video_ctool/ffmpeg_wrappers/ffmpeg_kit.dart';
import 'package:video_ctool/ffmpeg_wrappers/ffprobe_kit.dart';
import 'package:video_ctool/ffmpeg_wrappers/return_code.dart';
import 'package:video_ctool/utilitiesClass/actions_builder.dart';
import 'package:video_ctool/utilitiesClass/common_functions.dart';
import 'package:video_ctool/utilitiesClass/file_detail.dart';

void main() async {
  runApp(const MyApp());
}

const List<Widget> hint = [
  SelectableText(
      "• In your command, use the key @f_ to automatically replace it with the selected file's URL. \nexample:\n     (@f_ => '/0/download/input.mp4')\n"),
  SelectableText(
      "• For the output location, use the key @s_ to replace it with the download location '/0/download/' on your Android device. \nexample:\n     (@s_output.mp4 => '/0/download/output.mp4')\n"),
  SelectableText(
      "• Use the key @ext_ to replace it with the selected file’s extension. This helps in writing generic commands. \nexample:\n     (@s_output@ext_ => '/0/download/output.mp4')\n"),
  SelectableText(
      "• You can use @s_ to access additional files from the download folder, which can be useful for adding subtitles or audio to a video file.\n"),
  SelectableText(
      "• To keep this process running in the background, go to **Settings > Battery > Battery Optimization**, find this app, and select **Don't optimize**. This prevents the system from stopping the process when the app is not in use."),
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

const String space = '   ';
// StringBuffer writer, dynamic mapOfInformation
void streamsInformationTemplateGenerate(
    {required StringBuffer stringBuffer,
    required dynamic mapOfInformation,
    required List<int> countRefrence,
    required Map<Object?, Object?> formateInfo,
    required double totalSize}) {
  switch (mapOfInformation["codec_type"]) {
    case "video":
      stringBuffer.write('VIDEO:\n');
      stringBuffer.write('${space}Codec : ${mapOfInformation['codec_name']}\n');
      stringBuffer.write(
          '${space}Resolution : ${mapOfInformation['width']} x ${mapOfInformation['height']}\n');
      stringBuffer.write(
          '${space}Size : ${formatFileSize(mapOfInformation, formateInfo, totalSize)} \n');
      break;
    case "audio":
      if (countRefrence[0] == 0) {
        stringBuffer.write('AUDIO TRACKS:\n');
      }
      stringBuffer.write(' (${countRefrence[0]++})\n');
      stringBuffer.write('${space}Codec : ${mapOfInformation['codec_name']}\n');
      stringBuffer.write(
          '${space}Lang : ${getLanguageName(mapOfInformation['tags']?['language'])}\n');

      stringBuffer.write(
          '${space}Size : ${formatFileSize(mapOfInformation, formateInfo, totalSize)} \n');
      break;

    default:
  }
}

double? parseFrameRate(String? avgFrameRate) {
  if (avgFrameRate == null || !avgFrameRate.contains('/')) return null;

  try {
    final parts = avgFrameRate.split('/');
    final num numerator = num.tryParse(parts[0]) ?? 0;
    final num denominator = num.tryParse(parts[1]) ?? 1;

    if (denominator == 0) return null; // Prevent division by zero

    return numerator / denominator;
  } catch (e) {
    return null; // Return null on any unexpected error
  }
}

String capitalizeFirst(String text) {
  if (text.isEmpty) return "";
  return text[0].toUpperCase() + text.substring(1).toLowerCase();
}

double estimateAudioSize({
  required String codec,
  required int sampleRate,
  required double duration,
}) {
  // Approximate bitrates (bps) for different codecs
  Map<String, int> codecBitrates = {
    "vorbis": 128000, // Default Vorbis bitrate (128 kbps)
    "aac": 128000, // AAC (similar to Vorbis)
    "mp3": 192000, // MP3 commonly uses 192 kbps
    "opus": 96000, // Opus (highly efficient)
    "flac": 1000000, // FLAC (lossless, ~1 Mbps)
    "wav": sampleRate *
        16 *
        2, // WAV (PCM uncompressed: sampleRate × bitDepth × channels)
  };

  // Get bitrate or default to 128 kbps
  int bitrate = codecBitrates[codec.toLowerCase()] ?? 128000;

  // Calculate file size (bytes)
  double fileSizeBytes = (bitrate * duration) / 8;

  // Convert to MB
  return fileSizeBytes;
}

List<double> generalBppRange = [
  0.03, // Extremely efficient (e.g., AV1 at low bitrate)
  0.05, // Common for H.264, H.265, VP9 at lower bitrates
  0.08, // Medium quality across various codecs
  0.1, // Good balance of quality and efficiency
  0.15, // Higher quality, used for MPEG-4, VP9, high-bitrate H.264
  0.2, // Approaching lossless for some codecs
  0.25, // Very high quality, MPEG-2, unoptimized encodes
  0.3, // Near lossless or inefficient encoding
  0.35, // High-bitrate MPEG-2, archival quality
];

Map<String, List<double>> codecBppRanges = {
  "h264": [
    0.05,
    0.08,
    0.1,
    0.15,
    0.2
  ], // Common H.264 range from low to high quality
  "h265": [0.04, 0.06, 0.08, 0.1, 0.12], // H.265 (HEVC) is more efficient
  "vp9": [0.05, 0.07, 0.09, 0.12, 0.15], // VP9 range
  "av1": [0.03, 0.04, 0.06, 0.08, 0.1], // AV1 (most efficient)
  "mpeg4": [0.12, 0.15, 0.18, 0.2, 0.25], // MPEG-4 (older, less efficient)
  "mpeg2": [0.18, 0.2, 0.25, 0.3, 0.35], // MPEG-2 (least efficient)
};

double estimateVideoSize({
  required int width,
  required int height,
  required double frameRate,
  required double duration,
  required String codec,
  required double fileSize,
}) {
  // Default to H.264 if codec not found
  List<double> bpp = codecBppRanges[codec.toLowerCase()] ?? generalBppRange;

  double MayNearSize = 0;

  bool isactivateSkip = false;

  for (var perBpp in bpp) {
    if (!isactivateSkip) {
      double bitrate = width * height * frameRate * perBpp;

      double innerVideoFileSize = (bitrate * duration) / 8; // 8 bytes
      if (innerVideoFileSize < fileSize) {
        MayNearSize = innerVideoFileSize;
      } else {
        isactivateSkip = true;
      }
    }
  }
  return MayNearSize;
}

int convertToInt(String value) {
  return int.tryParse(value) ?? 0;
}

String formatFileSize(
    dynamic fileInfo, Map<Object?, Object?> format, double fileSize) {
  // Convert input strings to numbers
  int bitRate = int.tryParse(fileInfo['bit_rate'] ?? "0") ?? 0;
  double duration = double.tryParse(format['duration'].toString()) ?? 0.0;
  double totalBytes = 0.0;

  bool estimation = false;

  if (bitRate != 0 && duration != 0.0) {
    totalBytes = (bitRate * duration) / 8;
  } else if (fileInfo["codec_type"] == "video" &&
      fileInfo["codec_name"] != null &&
      duration != 0.0 &&
      fileInfo["width"] != null &&
      fileInfo["height"] != null &&
      parseFrameRate(fileInfo["avg_frame_rate"]) != null) {
    totalBytes = estimateVideoSize(
        codec: fileInfo["codec_name"],
        duration: duration,
        frameRate: parseFrameRate(fileInfo["avg_frame_rate"])!,
        height: fileInfo["height"],
        width: fileInfo["width"],
        fileSize: fileSize);
    estimation = true;
  } else if (fileInfo["codec_type"] == "audio" &&
      fileInfo["codec_name"] != null &&
      duration != 0.0 &&
      fileInfo["sample_rate"] != null) {
    totalBytes = estimateAudioSize(
        codec: fileInfo["codec_name"],
        duration: duration,
        sampleRate: convertToInt(fileInfo["sample_rate"]));
    estimation = true;
  }

  // Calculate total size in bytes

  // Convert to KB, MB, GB dynamically
  return bytesToSizeFormate(
      totalBytes,
      estimation == true
          ? '(${totalBytes == 0.0 ? 'Unable to calculate this stream.' : 'The size is calculation based, not exact.'})'
          : '(exact Size)');
}

String bytesToSizeFormate(double totalBytes, String include) {
  String result;
  if (totalBytes >= 1024 * 1024 * 1024) {
    result = "${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
  } else if (totalBytes >= 1024 * 1024) {
    result = "${(totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB";
  } else if (totalBytes >= 1024) {
    result = "${(totalBytes / 1024).toStringAsFixed(2)} KB";
  } else {
    result = "${totalBytes.toStringAsFixed(2)} Unknown";
  }
  return '$result $include';
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

    setState(() {
      _isError = false;
      logOutput.clear();
    });

    var status = await requestStoragePermission();
    if (selectedFilePath == null || conversionCommand.isEmpty || !status) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Error"),
          content: Text(status
              ? "Please select a file and enter a conversion command."
              : "Please provide storage permission, to store data on download"),
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
      _ConversionSessionOngoing = false;
      return;
    }
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
          title: const Text("Error"),
          content: const Text(
              "Conflicting flags: Both '-y' (overwrite) and '-n' (no overwrite) are present. Please provide only one."),
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

    setState(() {
      fullCommand = executableCommand;
      isConverting = true;
      progress = 0.0;
      _isError = false;
    });

    // Fetch total duration using FFprobe
    int totalDuration = await getVideoDuration(selectedFilePath!);
    String everyLoopLog = "";

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
              title: const Text("Success"),
              content: const Text("File converted successfully! Saved"),
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
                    title: const Text("Cancelled"),
                    content: const Text("File conversion was cancelled."),
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
              title: const Text("File Exists"),
              content: const Text(
                  "This file already exists. Enable overwrite? Press 'Start' again to begin conversion."),
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
                    title: const Text("Error"),
                    content: const Text(
                        "Conversion failed. Please check your command."),
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
  List<FileDetails> files = [];
  bool filterFileExtension = true;
  bool activetedfilter = false;
  List<FileDetails> filteredFiles = [];
  TextEditingController searchController = TextEditingController();
  Map<String, bool> listExtension = {
    // Video extensions
    ".mp4": true,
    ".mkv": true,
    ".mov": true,
    ".avi": true,
    ".wmv": true,
    ".flv": true,
    ".webm": true,
    ".mpeg": true,
    ".mpg": true,
    ".3gp": true,
    ".m4v": true,
    ".ts": true,

    //Audio extensions
    ".mp3": true,
    ".wav": true,
    ".aac": true,
    ".flac": true,
    ".ogg": true,
    ".wma": true,
    ".m4a": true,
    ".opus": true,
    ".alac": true,
    ".aiff": true,
    ".amr": true,
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
        activetedfilter = false;
        filteredFiles = [];
        searchController.text = "";
        _loadFiles();
      });
    }
  }

  void _loadFiles() {
    if (currentdir!.existsSync()) {
      setState(() {
        items = currentdir!.listSync();
        files = [];
        for (var fileData in items) {
          FileDetails calculatedFileInfo = FileDetails(fileData.path);
          if (calculatedFileInfo.getExtensionIfValidElseNull() != null) {
            files.add(calculatedFileInfo);
          }
        }
      });
    }
  }

  void _navigateToFolder(String path) {
    currentdir = Directory(path);
    setState(() {
      activetedfilter = false;
      filteredFiles = [];
      searchController.text = "";
      currentPath = path;
      _loadFiles();
    });
  }

  void _selectFile(String filePath) {
    String fileExtension =
        filePath.substring(filePath.lastIndexOf("."), filePath.length);
    if (listExtension[fileExtension] == true) {
      widget.updateVideoDetail(filePath);
      _convertVideo(filePath);
    } else {
      _showErrorDialog("Please select a valid Video/Audio file.");
    }
  }

  void _convertVideo(String filePath) {
    //print("Converting video: $filePath");
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
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6.0,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  hintText: "Search files...",
                  prefixIcon: Icon(Icons.search, color: Colors.blueGrey),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                ),
                onChanged: (query) {
                  setState(() {
                    activetedfilter = query.isNotEmpty;
                    filteredFiles = activetedfilter
                        ? files
                            .where((file) => file
                                .getFileNameInsmall()!
                                .contains(query.toLowerCase()))
                            .toList()
                        : [];
                  });
                },
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: activetedfilter ? filteredFiles.length : files.length,
              itemBuilder: (context, index) {
                List<FileDetails> data =
                    activetedfilter ? filteredFiles : files;
                FileDetails fileInfo = data[index];

                return ListTile(
                  leading: Icon(
                      fileInfo.isFolder() ? Icons.folder : Icons.video_file),
                  title: Text(fileInfo.getFileName()!),
                  onTap: () {
                    if (fileInfo.isFolder()) {
                      _navigateToFolder(fileInfo.getPath());
                    } else {
                      _selectFile(fileInfo.getPath());
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
  bool isLoading = true;
  @override
  void initState() {
    super.initState();
    commands = widget.commands;
    widget.loadListFun!((apiResult) {
      if (mounted) {
        setState(() {
          isLoading = false;
          commands = apiResult;
        });
      }
    });
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
        body: Stack(children: [
          commands.isEmpty
              ? const Center(
                  child: Text(
                    "No commands available.",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: commands.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final command = commands[index];

                    return Card(
                      elevation: 4,
                      shadowColor: Colors.blue.withOpacity(0.15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        leading: const Icon(
                          Icons.description, // Change icon as needed
                          color: Color(0xFF1565C0),
                          size: 28,
                        ),
                        title: Text(
                          capitalizeFirst(command[0] ?? "No Title Available"),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1565C0),
                            fontFamily: 'Menlo',
                            letterSpacing: 0.3,
                            height: 1.5,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF1565C0),
                          size: 24,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        onTap: () => _showCommandDetail(command, context),
                      ),
                    );
                  },
                ),
          if (isLoading) // 🔹 Show bottom loader only when loading
            Align(
              alignment: Alignment.bottomCenter,
              child: LinearProgressIndicator(
                backgroundColor: Colors.grey[300],
                color: Colors.blue.shade700,
                minHeight: 4,
              ),
            ),
        ]));
  }
}

//----------------------------------------------------------------------------------------x<

//---------------------------------------------------------------------------------------->

class CommandFormScreen extends StatefulWidget {
  final String workingCommand;
  final BuildContext parentContext;
  final bool isLocalSave;

  const CommandFormScreen(
      {super.key,
      required this.workingCommand,
      required this.parentContext,
      required this.isLocalSave});

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

  @override
  void initState() {
    _commandController.text = widget.workingCommand;
    super.initState();
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
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("Command saved!")));
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(widget.parentContext)
              .showSnackBar(const SnackBar(content: Text("Command saved!")));
        }
      }).catchError((error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("SomeThing went wrong")));
        } else {
          ScaffoldMessenger.of(widget.parentContext).showSnackBar(
              const SnackBar(content: Text("SomeThing went wrong")));
        }
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
                const Text(
                  "Share a helpful FFmpeg command to assist others in their workflows.",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                _buildTextField(_titleController, "Command Title"),
                const SizedBox(height: 20),
                _buildTextField(_commandController, "Command",
                    maxLines: 5, enable: widget.isLocalSave),
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
      {int maxLines = 1, bool enable = true}) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          enabled: enable,
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
  static const String spliter = ";";
  final Function(String) inputBoxController;
  final BuildContext parentContext;
  const CommandDetailScreen(
      {super.key,
      required this.command,
      required this.inputBoxController,
      required this.parentContext});

  void _copyCommand(BuildContext context, String cmd) {
    // Clipboard.setData(
    //     ClipboardData(text: Uri.decodeComponent(command[1]) ?? ""));
    inputBoxController(Uri.decodeComponent(cmd));
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
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Commands",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Splitting command[1] by ";"
                      ...(command[1] ?? "").isNotEmpty
                          ? (command[1])
                              .split(spliter)
                              .asMap()
                              .entries
                              .map<Widget>((entry) {
                              int index = entry.key;
                              String cmd = entry.value.trim();

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (index ==
                                      0) // Heading for the first command
                                    const Padding(
                                      padding: EdgeInsets.only(
                                          bottom: 8.0, top: 12.0),
                                      child: Text(
                                        "Main Command:",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    )
                                  else if (index ==
                                      1) // Heading for variations (shown only once)
                                    const Padding(
                                      padding: EdgeInsets.only(
                                          top: 12.0, bottom: 8.0),
                                      child: Text(
                                        "Variations:",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  Card(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    elevation: 3,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: ListTile(
                                      title: SelectableText(
                                        "${index + 1}. $cmd", // Adds numbering
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.copy,
                                            color: Colors.blue),
                                        onPressed: () =>
                                            _copyCommand(context, cmd),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            })
                          : [
                              Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                color: Colors.white,
                                child: const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "No command available.",
                                        style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ]
                    ],
                  ),
                ),
              ),

              // const SizedBox(height: 20),
              // Center(
              //   child: ElevatedButton.icon(
              //     onPressed: () => _copyCommand(context),
              //     icon: const Icon(Icons.copy, color: Colors.white),
              //     label: const Text(
              //       "Use this Command",
              //       style: TextStyle(
              //           fontSize: 16,
              //           fontWeight: FontWeight.w600,
              //           color: Colors.white),
              //     ),
              //     style: ElevatedButton.styleFrom(
              //       backgroundColor: Colors.blue.shade700,
              //       padding: const EdgeInsets.symmetric(
              //           vertical: 12, horizontal: 30),
              //       shape: RoundedRectangleBorder(
              //           borderRadius: BorderRadius.circular(30)),
              //       elevation: 6,
              //     ),
              //   ),
              // ),
              const SizedBox(height: 30),
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
                      SelectableText(
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

              // const SizedBox(height: 30),

              // // Copy Button
              // Center(
              //   child: ElevatedButton.icon(
              //     onPressed: () => _copyCommand(context),
              //     icon: const Icon(Icons.copy, color: Colors.white),
              //     label: const Text(
              //       "Use this Command",
              //       style: TextStyle(
              //           fontSize: 16,
              //           fontWeight: FontWeight.w600,
              //           color: Colors.white),
              //     ),
              //     style: ElevatedButton.styleFrom(
              //       backgroundColor: Colors.blue.shade700,
              //       padding: const EdgeInsets.symmetric(
              //           vertical: 12, horizontal: 30),
              //       shape: RoundedRectangleBorder(
              //           borderRadius: BorderRadius.circular(30)),
              //       elevation: 6,
              //     ),
              //   ),
              // ),
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

class SwipeButton extends StatefulWidget {
  final List<ActionBuilder>? actions;

  const SwipeButton({super.key, required this.actions});

  @override
  _SwipeButtonState createState() => _SwipeButtonState();
}

class _SwipeButtonState extends State<SwipeButton> {
  bool isSelectFile = true; // Tracks button state
  int currentButtonIndex = 0;
  int _actionLength = 0;
  bool _canSwipe = true;

  @override
  void initState() {
    super.initState();
    _actionLength = (widget.actions?.length ?? 0);
  }

  void _resetSwipe(DragEndDetails details) {
    setState(() {
      _canSwipe = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd:
          _resetSwipe, // reset on lift so again swipe to change another
      onVerticalDragUpdate: (details) {
        if (_canSwipe &&
            details.primaryDelta! < -6 &&
            (currentButtonIndex + 1) < _actionLength) {
          // logic is if it is swiped up and if

          setState(() {
            _canSwipe = false;
            ++currentButtonIndex;
          });
        } else if (_canSwipe &&
            details.primaryDelta! > 6 &&
            (currentButtonIndex - 1) > -1) {
          setState(() {
            _canSwipe = false;
            --currentButtonIndex;
          });
        }
      },
      child: ElevatedButton.icon(
        onPressed: () {
          widget.actions![currentButtonIndex].getOnSelectFun().call();
        },
        icon: Icon(widget.actions![currentButtonIndex].getIcon()),
        label: Text(widget.actions![currentButtonIndex].getName()),
      ),
    );
  }
}
