import 'dart:io';
import 'package:video_ctool/utils/constant.dart';

class FileDetails {
  final String _filePath;
  String _fileExtension = "";
  String _fileName = "";
  String _fileNameSmall = "";
  bool _isFolder = false;
  bool _isValidExtension = false;

  FileDetails(this._filePath) {
    bool isDir = FileSystemEntity.isDirectorySync(_filePath);
    if (isDir) {
      _isFolder = true;
      _isValidExtension = true;
      _fileName = _filePath.substring(_filePath.lastIndexOf("/") + 1);
      _fileNameSmall = _fileName.toLowerCase();
    } else if (_extractFileData(_filePath) &&
        LIST_EXTENSION[_fileExtension] == null) {
      _isValidExtension = false;
    }
  }

  bool isFolder() {
    return _isFolder;
  }

  String getPath() {
    return _filePath;
  }

  String? getExtensionIfValidElseNull() {
    return _isValidExtension ? _fileExtension : null;
  }

  String? getFileName() {
    return _fileName;
  }

  String? getFileNameInsmall() {
    return _fileNameSmall;
  }

  bool _extractFileData(String path) {
    int fileNameStart = -1;
    int extensionStart = -1;

    // Loop through the string once.
    for (int i = 0; i < path.length; i++) {
      final code = path.codeUnitAt(i);
      if (code == SLASH_CODE) {
        fileNameStart = i + 1;
      } else if (code == DOT_CODE && fileNameStart != -1) {
        // record dot position but keep updating if there's another dot later
        extensionStart = i;
      }
    }

    if (fileNameStart == -1) {
      // no slash found; the entire string is the file name
      fileNameStart = 0;
    }
    // Make sure the dot is part of the file name.
    if (extensionStart > fileNameStart) {
      _fileName = path.substring(fileNameStart);
      _fileNameSmall = _fileName.toLowerCase();
      _fileExtension = path.substring(extensionStart);
      _isValidExtension = true;
      return true;
    }

    return false;
  }
}
