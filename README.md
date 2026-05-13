# Where Soil Meets Intelligence: An AI-Powered IoT Advisory System for Smart Farming

This project presents an AI-powered IoT advisory system for smart farming. The system collects real-time soil and environmental sensor data, combines it with agricultural datasets, and uses a Large Language Model (LLM) to generate farmer-friendly crop advisories.

The main goal of this project is to support better farming decisions using real-time field data, historical agricultural data, and natural language explanations. Instead of only showing raw sensor values, the system converts the data into practical recommendations such as irrigation decisions, heat stress alerts, yield impact analysis, crop response explanation, and soil condition-based advisory.

---

## Project Overview

Modern farming requires timely and data-driven decisions. However, farmers may not always have the time or technical background to interpret sensor readings, weather trends, soil conditions, and yield records together.

This project addresses that gap by building an end-to-end system that connects:

- IoT-based field sensing
- Cloud-based data storage
- Agricultural data integration
- LLM-based advisory generation
- Mobile/web-based advisory access

The system is designed to take real-time and historical agricultural data and generate clear, actionable, and easy-to-understand advisories.

---

## System Architecture

The system follows a layered architecture:

1. **Physical Layer**
   - LoRaWAN-based IoT sensors collect field-level data.
   - Sensor values include soil moisture, temperature, and other environmental readings.

2. **Edge Layer**
   - A Raspberry Pi gateway receives sensor data.
   - Data is transmitted using MQTT/Wi-Fi.
   - The gateway forwards the data to the cloud.

3. **Cloud Layer**
   - AWS IoT Core receives incoming sensor messages.
   - AWS Lambda processes the data.
   - DynamoDB stores time-series sensor records.
   - AWS AppSync provides GraphQL API access.
   - AWS Amplify supports application deployment and integration.
   - AWS Cognito/IAM manages access control and authentication.

4. **AI Advisory Layer**
   - A FastAPI backend collects recent and historical context.
   - The backend prepares prompts using sensor and external agricultural data.
   - The prompt is sent to an LLM through Hugging Face Router.
   - LLaMA 3 is used to generate natural-language advisories.

5. **Application Layer**
   - A Flutter-based mobile application displays the advisory results.
   - Farmers can view sensor-based recommendations in simple language.

---

## Key Features

- Real-time soil and environmental monitoring
- Cloud-based storage of sensor data
- Integration of multiple agricultural datasets
- LLM-based natural language advisory generation
- Farmer-friendly recommendations
- Support for both immediate and detailed advisory questions
- Secure cloud access using AWS Cognito and IAM
- Mobile application interface using Flutter

---

## Advisory Use Cases

The system supports five main advisory prompts.

### 1. Immediate Irrigation Decision

This prompt uses recent sensor readings to decide whether irrigation is needed.

Example advisory question:

> Should I irrigate the field now based on the latest soil moisture and temperature values?

### 2. Heat Stress Alert

This prompt checks whether the crop may be experiencing heat stress based on recent temperature trends.

Example advisory question:

> Is the crop under heat stress right now?

### 3. Yield Impact Analysis

This prompt uses recent field conditions and historical agricultural data to explain how current conditions may affect yield.

Example advisory question:

> How will the current soil and weather conditions affect crop yield?

### 4. Crop Response to Changing Conditions

This prompt explains how the crop may respond to changes in soil moisture, temperature, and weather trends.

Example advisory question:

> How is the crop responding to recent environmental changes?

### 5. Soil Condition and Nutrient Advisory

This prompt analyzes soil condition and explains whether nutrient or soil-related limitations may affect crop growth.

Example advisory question:

> Is the crop performance limited by current soil condition or nutrient-related factors?

---

## Data Sources

The project uses both real-time sensor data and external agricultural datasets.

### Real-Time IoT Data

Sensor data is collected from LoRaWAN-based field sensors and stored in DynamoDB. Each record may include:

- Device ID
- Application ID
- Soil moisture
- Temperature
- Payload
- Timestamp

### External Agricultural Datasets

The system also uses publicly available agricultural datasets, including:

- **USDA SCAN**  
  Soil moisture and soil temperature data.

- **USDA NASS QuickStats**  
  Historical crop yield data.

- **Iowa Environmental Mesonet**  
  Weather and rainfall time-series data.

- **SoilGrids**  
  Soil properties such as pH, texture, and nutrient-related indicators.

---

## Technology Stack

### IoT and Edge

- LoRaWAN sensors
- Raspberry Pi gateway
- MQTT
- Wi-Fi
- The Things Network / The Things Cloud

### Cloud Services

- AWS IoT Core
- AWS Lambda
- AWS DynamoDB
- AWS AppSync
- AWS Amplify
- AWS Cognito
- AWS IAM

### AI and Backend

- FastAPI
- Hugging Face Router
- LLaMA 3
- Python

### Frontend

- Flutter
- GraphQL API integration

---

## AI Workflow

The AI advisory pipeline follows these steps:

1. Collect real-time sensor readings.
2. Retrieve recent field data from DynamoDB.
3. Combine sensor data with external agricultural datasets.
4. Construct a context-aware prompt.
5. Send the prompt to the LLM through the FastAPI backend.
6. Generate a farmer-friendly advisory.
7. Display the advisory in the mobile application.

The goal is not only to provide a prediction, but also to explain the reason behind the recommendation in clear language.

---

## Evaluation

The system was evaluated using two main metrics:

### 1. Query Response Time

Query Response Time measures how long the system takes to generate an advisory after receiving a request.

The instantaneous prompts, such as irrigation decision and heat stress alert, usually produced faster responses because they used smaller recent sensor contexts.

The detailed prompts, such as yield impact and crop response, took slightly longer because they required larger historical and contextual information.

### 2. Advisory Accuracy

Advisory Accuracy was evaluated using a soft scoring method based on four criteria:

- Relevance
- Correctness
- Actionability
- Clarity

The advisory accuracy score was calculated as:

```text
Advisory Accuracy = (Relevance + Correctness + Actionability + Clarity) / 4
