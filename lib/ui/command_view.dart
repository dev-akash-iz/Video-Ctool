import 'package:flutter/material.dart';
import 'package:video_ctool/ui/state_less/command_view_detail.dart';
import 'package:video_ctool/utils/atomic_functions.dart';

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
