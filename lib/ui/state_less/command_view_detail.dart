import 'package:flutter/material.dart';

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
