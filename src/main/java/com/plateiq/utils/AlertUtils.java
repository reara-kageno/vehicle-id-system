package com.plateiq.utils;

import javafx.scene.control.Alert;
import javafx.scene.control.ButtonType;
import javafx.scene.control.DialogPane;
import javafx.scene.paint.Color;
import javafx.scene.effect.DropShadow;
import javafx.scene.text.Font;

// Utility class for displaying alert dialogs.
public class AlertUtils {
    
    // Shows an error dialog with the specified title and message.
    public static void showError(String title, String message) {
        Alert alert = new Alert(Alert.AlertType.ERROR);
        alert.setTitle(title);
        alert.setHeaderText(null);
        alert.setContentText(message);
        alert.getDialogPane().setStyle("-fx-background-color: #f8d7da; -fx-border-color: #f5c6cb;");
        alert.showAndWait();
    }

    public static void showError(String message) {
        showError("Error", message);
    }
    
    // Shows an error dialog with the specified title, header, and message.
    public static void showError(String title, String header, String message) {
        Alert alert = new Alert(Alert.AlertType.ERROR);
        alert.setTitle(title);
        alert.setHeaderText(header);
        alert.setContentText(message);
        alert.getDialogPane().setStyle("-fx-background-color: #f8d7da; -fx-border-color: #f5c6cb;");
        alert.showAndWait();
    }
    
    // Shows an info dialog with the specified title and message.
    public static void showInfo(String title, String message) {
        Alert alert = new Alert(Alert.AlertType.INFORMATION);
        alert.setTitle(title);
        alert.setHeaderText(null);
        alert.setContentText(message);
        alert.getDialogPane().setStyle("-fx-background-color: #d1ecf1; -fx-border-color: #bee5eb;");
        alert.showAndWait();
    }

    public static void showInfo(String message) {
        showInfo("Info", message);
    }
    
    // Shows an info dialog with the specified title, header, and message.
    public static void showInfo(String title, String header, String message) {
        Alert alert = new Alert(Alert.AlertType.INFORMATION);
        alert.setTitle(title);
        alert.setHeaderText(header);
        alert.setContentText(message);
        alert.getDialogPane().setStyle("-fx-background-color: #d1ecf1; -fx-border-color: #bee5eb;");
        alert.showAndWait();
    }
    
    //Shows a warning dialog with the specified title and message.
    public static void showWarning(String title, String message) {
        Alert alert = new Alert(Alert.AlertType.WARNING);
        alert.setTitle(title);
        alert.setHeaderText(null);
        alert.setContentText(message);
        alert.getDialogPane().setStyle("-fx-background-color: #fff3cd; -fx-border-color: #ffeeba;");
        alert.showAndWait();
    }

    public static void showWarning(String message) {
        showWarning("Warning", message);
    }
    
    // Shows a warning dialog with the specified title, header, and message.
    public static void showWarning(String title, String header, String message) {
        Alert alert = new Alert(Alert.AlertType.WARNING);
        alert.setTitle(title);
        alert.setHeaderText(header);
        alert.setContentText(message);
        alert.getDialogPane().setStyle("-fx-background-color: #fff3cd; -fx-border-color: #ffeeba;");
        alert.showAndWait();
    }
    
    // Shows a confirmation dialog with the specified title and message.
    public static boolean showConfirmation(String title, String message) {
        Alert alert = new Alert(Alert.AlertType.CONFIRMATION);
        alert.setTitle(title);
        alert.setHeaderText(null);
        alert.setContentText(message);
        alert.getDialogPane().setStyle("-fx-background-color: #d1e7dd; -fx-border-color: #badbcc;");
        
        ButtonType okButton = new ButtonType("OK");
        ButtonType cancelButton = new ButtonType("Cancel", ButtonType.ButtonData.CANCEL_CLOSE);
        alert.getButtonTypes().setAll(okButton, cancelButton);
        
        return alert.showAndWait().orElse(cancelButton) == okButton;
    }
    
    // Shows a confirmation dialog with the specified title, header, and message.
    public static boolean showConfirmation(String title, String header, String message) {
        Alert alert = new Alert(Alert.AlertType.CONFIRMATION);
        alert.setTitle(title);
        alert.setHeaderText(header);
        alert.setContentText(message);
        alert.getDialogPane().setStyle("-fx-background-color: #d1e7dd; -fx-border-color: #badbcc;");
        
        ButtonType okButton = new ButtonType("OK");
        ButtonType cancelButton = new ButtonType("Cancel", ButtonType.ButtonData.CANCEL_CLOSE);
        alert.getButtonTypes().setAll(okButton, cancelButton);
        
        return alert.showAndWait().orElse(cancelButton) == okButton;
    }
    
    // Applies a DropShadow effect to a DialogPane for visual enhancement.
    public static void applyDropShadow(DialogPane dialogPane) {
        DropShadow dropShadow = new DropShadow();
        dropShadow.setRadius(10);
        dropShadow.setOffsetX(3);
        dropShadow.setOffsetY(3);
        dropShadow.setColor(Color.color(0.4, 0.4, 0.4));
        dialogPane.setEffect(dropShadow);
    }
    
    // Sets a modern font style for alert dialogs.
    public static void applyModernFont(DialogPane dialogPane) {
        dialogPane.setStyle("-fx-font-family: 'Segoe UI', Arial, sans-serif;");
    }
}
