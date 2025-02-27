package com.devakash.ctool;


import android.os.Bundle;
import android.view.KeyEvent;
import androidx.annotation.NonNull;
import io.flutter.plugin.common.MethodChannel;
import android.content.Intent;
import android.os.Handler;
import android.widget.Toast;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugins.GeneratedPluginRegistrant;
import com.arthenica.ffmpegkit.flutter.FFmpegKitFlutterPlugin;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.devakash/backButtonIntermediate";
    private MethodChannel methodChannel;
    private int count = 0;


    
    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        methodChannel = new MethodChannel(getFlutterEngine().getDartExecutor(), CHANNEL);
        // Ensures Flutter recognizes all auto-registered plugins
        GeneratedPluginRegistrant.registerWith(flutterEngine);

        // Manually register FFmpegKit plugin if it’s not auto-registered
        flutterEngine.getPlugins().add(new FFmpegKitFlutterPlugin());
    }

    @Override
    public void onBackPressed() {
         methodChannel.invokeMethod("handleBackButtonPress", null, new MethodChannel.Result() {
                @Override
                public void success(Object result) {
                    
                    if (result instanceof Boolean && (Boolean) result) {
                        Toast.makeText(MainActivity.this, "Conversion in progress... Feel free to minimize.", Toast.LENGTH_SHORT).show();
                    } else {
                        backButtonCloseCustom();
                        //System.out.println("Flutter returned false");
                    }
                }

                @Override
                public void error(String errorCode, String errorMessage, Object errorDetails) {
                    //System.out.println("Error calling Flutter: " + errorMessage);
                }

                @Override
                public void notImplemented() {
                    //System.out.println("Method not implemented");
                }
            });
                
        
    }

    private void backButtonCloseCustom(){
               if (count >= 1) {
                    // If the back button is pressed again within 2 seconds, exit the app or perform any action
                    finishAffinity();
                } else {
                    // Show a toast message to inform the user
                    Toast.makeText(this, "Press back again to exit", Toast.LENGTH_SHORT).show();

                    // Increment the counter
                    count++;

                    // Reset the counter in 2 seconds
                    new Handler().postDelayed(new Runnable() {
                        @Override
                        public void run() {
                            count = 0;
                        }
                    }, 2000);
                }
    }
}