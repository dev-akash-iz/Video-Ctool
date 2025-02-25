package com.devakash.ctool;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugins.GeneratedPluginRegistrant;
import com.arthenica.ffmpegkit.flutter.FFmpegKitFlutterPlugin;

public class MainActivity extends FlutterActivity {
    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        
        // Ensures Flutter recognizes all auto-registered plugins
        GeneratedPluginRegistrant.registerWith(flutterEngine);

        // Manually register FFmpegKit plugin if it’s not auto-registered
        flutterEngine.getPlugins().add(new FFmpegKitFlutterPlugin());
    }
}