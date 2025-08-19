package com.rainfall.backend.dto;
public record PredictResponse(double probability,String label,double confidence) {}
