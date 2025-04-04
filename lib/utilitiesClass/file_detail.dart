import 'dart:io';

class FileDetails {
  final String _filePath;
  String _fileExtension = "";
  String _fileName = "";
  String _fileNameSmall = "";
  bool _isFolder = false;
  bool _isValidExtension = false;

  final Map<String, bool> _listExtension = {
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

  FileDetails(this._filePath) {
    bool isDir = FileSystemEntity.isDirectorySync(_filePath);
    if (isDir) {
      _isFolder = true;
      _isValidExtension = true;
      _fileName = _filePath.substring(_filePath.lastIndexOf("/") + 1);
      _fileNameSmall = _fileName.toLowerCase();
    } else if (_extractFileData(_filePath) &&
        _listExtension[_fileExtension] == null) {
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
    final slashCode = '/'.codeUnitAt(0);
    final dotCode = '.'.codeUnitAt(0);

    // Loop through the string once.
    for (int i = 0; i < path.length; i++) {
      final code = path.codeUnitAt(i);
      if (code == slashCode) {
        fileNameStart = i + 1;
      } else if (code == dotCode && fileNameStart != -1) {
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
