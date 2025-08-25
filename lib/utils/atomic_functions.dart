import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:video_ctool/utils/constant.dart';

String getLanguageName(String? code) {
  if (code == null || code.isEmpty) {
    return "Unknown";
  }
  return LANGUAGE_NAME[code] ?? code;
}

String formatDuration(dynamic duration) {
  double seconds = double.tryParse(duration.toString()) ?? 0.0;
  int totalSeconds = seconds.round(); // Convert to nearest whole number
  int hours = totalSeconds ~/ 3600;
  int minutes = (totalSeconds % 3600) ~/ 60;
  int secs = totalSeconds % 60;

  // Build formatted output dynamically
  List<String> parts = [];
  if (hours > 0) parts.add('${hours}h');
  if (minutes > 0) parts.add('${minutes}m');
  if (secs > 0 || parts.isEmpty) parts.add('${secs}s');

  return parts.join(" "); // Example: "1h 23m 10s"
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

void streamsInformationTemplateGenerate(
    {required StringBuffer stringBuffer,
    required dynamic mapOfInformation,
    required List<int> countRefrence,
    required Map<Object?, Object?> formateInfo,
    required double totalSize}) {
  switch (mapOfInformation["codec_type"]) {
    case "video":
      stringBuffer.write('VIDEO:\n');
      stringBuffer.write('${SPACE}Codec : ${mapOfInformation['codec_name']}\n');
      stringBuffer.write(
          '${SPACE}Resolution : ${mapOfInformation['width']} x ${mapOfInformation['height']}\n');
      stringBuffer.write(
          '${SPACE}Size : ${formatFileSize(mapOfInformation, formateInfo, totalSize)} \n');
      break;
    case "audio":
      if (countRefrence[0] == 0) {
        stringBuffer.write('AUDIO TRACKS:\n');
      }
      stringBuffer.write(' (${countRefrence[0]++})\n');
      stringBuffer.write('${SPACE}Codec : ${mapOfInformation['codec_name']}\n');
      stringBuffer.write(
          '${SPACE}Lang : ${getLanguageName(mapOfInformation['tags']?['language'])}\n');

      stringBuffer.write(
          '${SPACE}Size : ${formatFileSize(mapOfInformation, formateInfo, totalSize)} \n');
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

double estimateVideoSize({
  required int width,
  required int height,
  required double frameRate,
  required double duration,
  required String codec,
  required double fileSize,
}) {
  // Default to H.264 if codec not found
  List<double> bpp = CODEC_BPP_RANGES[codec.toLowerCase()] ?? GENERAL_BPP_RANGE;

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

bool stringIsEmpty(String? value) {
  return value == null || value.isEmpty;
}

String alertUserOnIssueOnStart(
    bool isFileNotPresent, bool isCommandNotPresent) {
  if (isFileNotPresent && isCommandNotPresent) {
    return "Please select a file and enter a conversion command.";
  } else if (isFileNotPresent) {
    return "Please select a file.";
  } else if (isCommandNotPresent) {
    return "Please enter a conversion command.";
  }

  return "";
}
