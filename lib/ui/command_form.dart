import 'package:flutter/material.dart';
import 'package:video_ctool/api/api_layer.dart';

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
