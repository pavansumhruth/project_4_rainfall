package com.rainfall.backend.controller;
import com.rainfall.backend.dto.PredictRequest;
import com.rainfall.backend.dto.PredictResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestTemplate;
@RestController
public class PredictController {
    private final String mlServiceUrl;
    public PredictController(@Value("${ml.service-url:http://localhost:8000}") String mlServiceUrl) { this.mlServiceUrl = mlServiceUrl; }
    @PostMapping("/api/predict")
    public ResponseEntity<PredictResponse> predict(@RequestBody PredictRequest request) {
        try {
            RestTemplate rest = new RestTemplate();
            String url = mlServiceUrl + "/predict";
            PredictResponse response = rest.postForObject(url, request, PredictResponse.class);
            if (response == null) return ResponseEntity.ok(fallbackPredict(request));
            return ResponseEntity.ok(response);
        } catch (Exception ex) { return ResponseEntity.ok(fallbackPredict(request)); }
    }
    private PredictResponse fallbackPredict(PredictRequest r) {
        double score = 0.03 * (r.temperature() - 20.0) + 0.20 * r.humidity() - 0.01 * (r.pressure() - 1010.0) - 0.05 * r.windSpeed();
        double probability = 1.0 / (1.0 + Math.exp(-score));
        String label = probability >= 0.5 ? "rain" : "no_rain";
        double confidence = Math.abs(probability - 0.5) * 2.0;
        return new PredictResponse(probability, label, confidence);
    }
}
