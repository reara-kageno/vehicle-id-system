package com.plateiq.utils;

import java.io.FileWriter;
import java.io.IOException;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;

import com.plateiq.model.Vehicle;
//Utility class for exporting data to text files.
public class ReportExporter {
    
    private static final DateTimeFormatter DATE_FORMATTER = 
        DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
    
    //Exports a vehicle report to a text file.
    public static boolean exportVehicleReport(Vehicle vehicle, String filename) {
        StringBuilder content = new StringBuilder();
        content.append("========================================\n");
        content.append("         PLATE IQ - VEHICLE REPORT      \n");
        content.append("========================================\n");
        content.append("Generated: ").append(LocalDateTime.now().format(DATE_FORMATTER)).append("\n\n");
        
        if (vehicle != null) {
            content.append("VEHICLE DETAILS\n");
            content.append("----------------------------------------\n");
            content.append("Registration Number: ").append(vehicle.getRegistrationNumber()).append("\n");
            content.append("Make: ").append(vehicle.getMake()).append("\n");
            content.append("Model: ").append(vehicle.getModel()).append("\n");
            content.append("Year: ").append(vehicle.getYear()).append("\n");
            content.append("Color: ").append(vehicle.getColor()).append("\n");
            content.append("Owner Name: ").append(vehicle.getOwnerName()).append("\n");
            content.append("Owner Phone: ").append(vehicle.getOwnerPhone()).append("\n");
            content.append("Vehicle ID: ").append(vehicle.getVehicleId()).append("\n");
        } else {
            content.append("No vehicle data available.\n");
        }
        
        content.append("\n========================================\n");
        content.append("         END OF REPORT                 \n");
        content.append("========================================\n");
        
        return writeToFile(content.toString(), filename);
    }
    
    //Exports a list of vehicles to a text file.
    public static boolean exportVehicleList(List<Vehicle> vehicles, String filename) {
        StringBuilder content = new StringBuilder();
        content.append("========================================\n");
        content.append("         PLATE IQ - VEHICLE LIST        \n");
        content.append("========================================\n");
        content.append("Generated: ").append(LocalDateTime.now().format(DATE_FORMATTER)).append("\n");
        content.append("Total Vehicles: ").append(vehicles != null ? vehicles.size() : 0).append("\n\n");
        
        if (vehicles != null && !vehicles.isEmpty()) {
            for (int i = 0; i < vehicles.size(); i++) {
                Vehicle vehicle = vehicles.get(i);
                content.append("VEHICLE #").append(i + 1).append("\n");
                content.append("----------------------------------------\n");
                content.append("Registration: ").append(vehicle.getRegistrationNumber()).append("\n");
                content.append("Make: ").append(vehicle.getMake()).append("\n");
                content.append("Model: ").append(vehicle.getModel()).append("\n");
                content.append("Year: ").append(vehicle.getYear()).append("\n");
                content.append("Color: ").append(vehicle.getColor()).append("\n");
                content.append("Owner: ").append(vehicle.getOwnerName()).append("\n");
                content.append("\n");
            }
        } else {
            content.append("No vehicles found.\n");
        }
        
        content.append("========================================\n");
        content.append("         END OF REPORT                 \n");
        content.append("========================================\n");
        
        return writeToFile(content.toString(), filename);
    }
    
    //Exports a customer query log to a text file.
    public static boolean exportCustomerQuery(String queryText, String filename) {
        StringBuilder content = new StringBuilder();
        content.append("========================================\n");
        content.append("       PLATE IQ - CUSTOMER QUERY        \n");
        content.append("========================================\n");
        content.append("Date: ").append(LocalDateTime.now().format(DATE_FORMATTER)).append("\n\n");
        content.append("QUERY:\n");
        content.append("----------------------------------------\n");
        content.append(queryText).append("\n");
        content.append("----------------------------------------\n");
        content.append("\n========================================\n");
        content.append("         END OF QUERY                  \n");
        content.append("========================================\n");
        
        return writeToFile(content.toString(), filename);
    }
    
    //Writes content to a text file.
    private static boolean writeToFile(String content, String filename) {
        try (FileWriter writer = new FileWriter(filename)) {
            writer.write(content);
            return true;
        } catch (IOException e) {
            AlertUtils.showError("Export Error", 
                "Failed to export report to file: " + filename);
            return false;
        }
    }

    // Exports custom text content to a file.
    public static boolean exportToFile(String content, String filename) {
        return writeToFile(content, filename);
    }
    
    // Exports an error log to a text file.
    public static boolean exportErrorLog(String errorMessage, String filename) {
        StringBuilder content = new StringBuilder();
        content.append("========================================\n");
        content.append("         PLATE IQ - ERROR LOG           \n");
        content.append("========================================\n");
        content.append("Date: ").append(LocalDateTime.now().format(DATE_FORMATTER)).append("\n\n");
        content.append("ERROR:\n");
        content.append("----------------------------------------\n");
        content.append(errorMessage).append("\n");
        content.append("----------------------------------------\n");
        content.append("\n========================================\n");
        content.append("         END OF LOG                    \n");
        content.append("========================================\n");
        
        return writeToFile(content.toString(), filename);
    }
}
