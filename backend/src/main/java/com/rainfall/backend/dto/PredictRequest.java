package com.rainfall.backend.dto;
public record PredictRequest(double temperature,double humidity,double pressure,double windSpeed,String region) {}
