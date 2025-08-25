import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_ctool/utils/class_entity/file_detail.dart';
import 'package:video_ctool/utils/constant.dart';
import 'package:path/path.dart' as path;

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
  State<CustomFilePicker> createState() => _CustomFilePickerState();
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
    if (LIST_EXTENSION[fileExtension] == true) {
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
        title: const Text("Error", textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
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
