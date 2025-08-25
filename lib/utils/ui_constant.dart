import 'package:flutter/material.dart';

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
