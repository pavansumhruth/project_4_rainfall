package com.rainfall.backend.controller;

import com.rainfall.backend.dto.PredictRequest;
import com.rainfall.backend.dto.PredictResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestTemplate;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@RestController
public class PredictController {
    private static final Logger log = LoggerFactory.getLogger(PredictController.class);
    private final String mlServiceUrl;
    private final RestTemplate restTemplate;

    public PredictController(
            @Value("${ml.service-url:http://localhost:8000}") String mlServiceUrl,
            RestTemplate restTemplate
    ) {
        this.mlServiceUrl = mlServiceUrl;
        this.restTemplate = restTemplate;
    }

    @PostMapping("/api/predict")
    public ResponseEntity<PredictResponse> predict(@RequestBody PredictRequest request) {
        long startNs = System.nanoTime();
        try {
            String url = mlServiceUrl + "/predict";
            PredictResponse response = restTemplate.postForObject(url, request, PredictResponse.class);
            if (response == null) {
                log.warn("ML service returned null response, using fallback.");
                return ResponseEntity.ok(fallbackPredict(request));
            }
            long tookMs = (System.nanoTime() - startNs) / 1_000_000;
            log.info("ML predict ok in {} ms", tookMs);
            return ResponseEntity.ok(response);
        } catch (Exception ex) {
            long tookMs = (System.nanoTime() - startNs) / 1_000_000;
            log.warn("ML predict failed in {} ms: {}. Using fallback.", tookMs, ex.toString());
            return ResponseEntity.ok(fallbackPredict(request));
        }
    }

    private PredictResponse fallbackPredict(PredictRequest r) {
        double score = 0.03 * (r.temperature() - 20.0) + 0.20 * r.humidity() - 0.01 * (r.pressure() - 1010.0) - 0.05 * r.windSpeed();
        double probability = 1.0 / (1.0 + Math.exp(-score));
        String label = probability >= 0.5 ? "rain" : "no_rain";
        double confidence = Math.abs(probability - 0.5) * 2.0;
        return new PredictResponse(probability, label, confidence);
    }
}
