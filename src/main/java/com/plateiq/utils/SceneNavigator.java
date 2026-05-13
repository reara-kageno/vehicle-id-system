package com.plateiq.utils;

import java.io.IOException;

import javafx.event.ActionEvent;
import javafx.fxml.FXMLLoader;
import javafx.scene.Parent;
import javafx.scene.Scene;
import javafx.stage.Stage;

// Utility class for managing scene transitions between FXML views.
public class SceneNavigator {

    // Switches to a new scene based on the provided FXML path.
    public static void switchScene(ActionEvent event, String fxmlPath) {
        try {
            // Get the current stage from the event
            Stage stage = (Stage) ((javafx.scene.Node) event.getSource()).getScene().getWindow();
            java.net.URL resource = SceneNavigator.class.getResource(fxmlPath);
            if (resource == null) {
                throw new IOException("FXML not found: " + fxmlPath);
            }

            Parent root = FXMLLoader.load(resource);
            
            // Create a new scene with the loaded FXML
            Scene newScene = new Scene(root);
            
            // Set the new scene on the stage
            stage.setScene(newScene);
            
            // Show the new scene
            stage.show();
        } catch (IOException e) {
            AlertUtils.showError("Scene Load Error", "Failed to load FXML: " + fxmlPath);
            e.printStackTrace();
        }
    }
}
