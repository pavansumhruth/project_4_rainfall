set -euo pipefail
git init -b main >/dev/null 2>&1 || true

# .gitignore
cat > .gitignore << "EOF"
# General
.DS_Store
Thumbs.db
.idea/
.vscode/
*.log
*.tmp
*.swp
.env
.venv/

# Java / Maven
target/
*.iml
.mvn/wrapper/
mvnw
mvnw.cmd

# Node / Vite
node_modules/
dist/
.pnpm-store/
.yarn/
.turbo/

# Python
__pycache__/
.pytest_cache/
.mypy_cache/
.ruff_cache/
.coverage*

# Docker
*.local.yml
EOF

# .editorconfig
cat > .editorconfig << "EOF"
root = true

[*]
indent_style = space
indent_size = 2
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true

[*.java]
indent_size = 4
EOF

# .env.example
cat > .env.example << "EOF"
BACKEND_PORT=8080
ML_SERVICE_PORT=8000
FRONTEND_PORT=5173
VITE_BACKEND_URL=http://localhost:${BACKEND_PORT}
VITE_ML_SERVICE_URL=http://localhost:${ML_SERVICE_PORT}
POSTGRES_DB=rainfalldb
POSTGRES_USER=rainfall
POSTGRES_PASSWORD=rainfall
POSTGRES_PORT=5432
ML_SERVICE_URL=http://ml-service:${ML_SERVICE_PORT}
CORS_ALLOWED_ORIGINS=*
EOF

# docker-compose.yml
cat > docker-compose.yml << "EOF"
version: "3.9"
name: rainfall-prediction-system
services:
  postgres:
    image: postgres:16-alpine
    container_name: rps-postgres
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-rainfalldb}
      POSTGRES_USER: ${POSTGRES_USER:-rainfall}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-rainfall}
    ports:
      - "${POSTGRES_PORT:-5432}:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks: [app-net]

  ml-service:
    build: { context: ./ml-service }
    container_name: rps-ml-service
    environment: [ "PORT=${ML_SERVICE_PORT:-8000}" ]
    ports: [ "${ML_SERVICE_PORT:-8000}:8000" ]
    networks: [app-net]

  backend:
    build: { context: ./backend }
    container_name: rps-backend
    environment:
      - SERVER_PORT=${BACKEND_PORT:-8080}
      - SPRING_PROFILES_ACTIVE=dev
      - CORS_ALLOWED_ORIGINS=${CORS_ALLOWED_ORIGINS:-*}
      - ML_SERVICE_URL=${ML_SERVICE_URL:-http://ml-service:8000}
    depends_on: [ml-service]
    ports: [ "${BACKEND_PORT:-8080}:8080" ]
    networks: [app-net]

  frontend:
    build: { context: ./frontend }
    container_name: rps-frontend
    environment:
      - VITE_BACKEND_URL=http://localhost:${BACKEND_PORT:-8080}
      - VITE_ML_SERVICE_URL=http://localhost:${ML_SERVICE_PORT:-8000}
      - PORT=${FRONTEND_PORT:-5173}
    ports: [ "${FRONTEND_PORT:-5173}:5173" ]
    depends_on: [backend]
    networks: [app-net]

volumes:
  postgres-data:

networks:
  app-net: { driver: bridge }
EOF

# Backend (Spring Boot)
mkdir -p backend/src/main/java/com/rainfall/backend/{config,controller,dto} backend/src/main/resources
cat > backend/pom.xml << "EOF"
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <parent><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-parent</artifactId><version>3.3.3</version><relativePath/></parent>
  <groupId>com.rainfall</groupId><artifactId>backend</artifactId><version>0.0.1-SNAPSHOT</version><name>backend</name>
  <properties><java.version>17</java.version></properties>
  <dependencies>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-web</artifactId></dependency>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-security</artifactId></dependency>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-validation</artifactId></dependency>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-test</artifactId><scope>test</scope></dependency>
  </dependencies>
  <build><plugins><plugin><groupId>org.springframework.boot</groupId><artifactId>spring-boot-maven-plugin</artifactId></plugin></plugins></build>
</project>
EOF

cat > backend/src/main/resources/application.yml << "EOF"
server:
  port: ${SERVER_PORT:8080}
spring:
  main:
    banner-mode: "off"
ml:
  service-url: ${ML_SERVICE_URL:http://ml-service:8000}
cors:
  allowed-origins: ${CORS_ALLOWED_ORIGINS:*}
EOF

cat > backend/src/main/java/com/rainfall/backend/BackendApplication.java << "EOF"
package com.rainfall.backend;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
@SpringBootApplication
public class BackendApplication {
    public static void main(String[] args) { SpringApplication.run(BackendApplication.class, args); }
}
EOF

cat > backend/src/main/java/com/rainfall/backend/config/SecurityConfig.java << "EOF"
package com.rainfall.backend.config;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;
@Configuration
public class SecurityConfig {
    @Bean
    SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http.csrf(csrf -> csrf.disable()).cors(cors -> {}).authorizeHttpRequests(auth -> auth.anyRequest().permitAll());
        return http.build();
    }
}
EOF

cat > backend/src/main/java/com/rainfall/backend/config/CorsConfig.java << "EOF"
package com.rainfall.backend.config;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import java.util.Arrays;
@Configuration
public class CorsConfig {
    @Bean
    CorsConfigurationSource corsConfigurationSource(@Value("${cors.allowed-origins:*}") String allowedOrigins) {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOriginPatterns(Arrays.asList(allowedOrigins.split(",")));
        config.setAllowedMethods(Arrays.asList("GET","POST","PUT","DELETE","OPTIONS"));
        config.setAllowedHeaders(Arrays.asList("*"));
        config.setAllowCredentials(false);
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }
}
EOF

cat > backend/src/main/java/com/rainfall/backend/controller/HealthController.java << "EOF"
package com.rainfall.backend.controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.Map;
@RestController
public class HealthController {
    @GetMapping("/api/health")
    public Map<String, String> health() { return Map.of("status", "ok"); }
}
EOF

cat > backend/src/main/java/com/rainfall/backend/dto/PredictRequest.java << "EOF"
package com.rainfall.backend.dto;
public record PredictRequest(double temperature,double humidity,double pressure,double windSpeed,String region) {}
EOF

cat > backend/src/main/java/com/rainfall/backend/dto/PredictResponse.java << "EOF"
package com.rainfall.backend.dto;
public record PredictResponse(double probability,String label,double confidence) {}
EOF

cat > backend/src/main/java/com/rainfall/backend/controller/PredictController.java << "EOF"
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
EOF

cat > backend/Dockerfile << "EOF"
FROM maven:3.9.6-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn -q -e -B -DskipTests dependency:go-offline
COPY src ./src
RUN mvn -q -e -B -DskipTests package
FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=build /app/target/backend-0.0.1-SNAPSHOT.jar /app/app.jar
EXPOSE 8080
ENV JAVA_OPTS=""
ENTRYPOINT ["sh","-lc","java $JAVA_OPTS -jar /app/app.jar"]
EOF

# ML service (FastAPI)
mkdir -p ml-service/app
cat > ml-service/requirements.txt << "EOF"
fastapi==0.111.0
uvicorn[standard]==0.30.0
pydantic==2.8.2
EOF
cat > ml-service/app/main.py << "EOF"
from fastapi import FastAPI
from pydantic import BaseModel
import math
app = FastAPI()
class PredictRequest(BaseModel):
    temperature: float
    humidity: float
    pressure: float
    windSpeed: float
    region: str | None = None
class PredictResponse(BaseModel):
    probability: float
    label: str
    confidence: float
@app.get("/health")
def health():
    return {"status": "ok"}
@app.post("/predict", response_model=PredictResponse)
def predict(req: PredictRequest):
    score = 0.03 * (req.temperature - 20.0) + 0.20 * req.humidity - 0.01 * (req.pressure - 1010.0) - 0.05 * req.windSpeed
    p = 1.0 / (1.0 + math.exp(-score))
    label = "rain" if p >= 0.5 else "no_rain"
    confidence = abs(p - 0.5) * 2.0
    return {"probability": p, "label": label, "confidence": confidence}
EOF
cat > ml-service/Dockerfile << "EOF"
FROM python:3.11-slim
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt
COPY app /app/app
EXPOSE 8000
ENV PORT=8000
CMD ["sh","-lc","uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
EOF

# Frontend (Vite-like minimal)
mkdir -p frontend/src
cat > frontend/package.json << "EOF"
{
  "name": "frontend",
  "private": true,
  "version": "0.0.1",
  "type": "module",
  "scripts": { "dev": "vite", "build": "vite build", "preview": "vite preview --host" },
  "dependencies": { "react": "^18.2.0", "react-dom": "^18.2.0" },
  "devDependencies": { "@types/react": "^18.2.74", "@types/react-dom": "^18.2.24", "@vitejs/plugin-react": "^4.3.1", "typescript": "^5.4.5", "vite": "^5.3.1" }
}
EOF
cat > frontend/tsconfig.json << "EOF"
{
  "compilerOptions": { "target": "ES2020","useDefineForClassFields": true,"lib": ["ES2020","DOM","DOM.Iterable"],"module": "ESNext","skipLibCheck": true,"jsx": "react-jsx","moduleResolution": "bundler","resolveJsonModule": true,"isolatedModules": true,"noEmit": true,"allowJs": false,"strict": true },
  "include": ["src"]
}
EOF
cat > frontend/vite.config.ts << "EOF"
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
export default defineConfig({ plugins: [react()], server: { host: "0.0.0.0", port: parseInt(process.env.PORT || "5173", 10) }});
EOF
cat > frontend/index.html << "EOF"
<!doctype html><html lang="en"><head><meta charset="UTF-8"/><meta name="viewport" content="width=device-width, initial-scale=1.0"/><title>Rainfall Prediction</title></head><body><div id="root"></div><script type="module" src="/src/main.tsx"></script></body></html>
EOF
cat > frontend/src/main.tsx << "EOF"
import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
ReactDOM.createRoot(document.getElementById("root")!).render(<React.StrictMode><App /></React.StrictMode>);
EOF
cat > frontend/src/App.tsx << "EOF"
import React, { useState } from "react";
const backendUrl = import.meta.env.VITE_BACKEND_URL || "http://localhost:8080";
export default function App() {
  const [form, setForm] = useState({ temperature: 29.4, humidity: 0.78, pressure: 1006.5, windSpeed: 4.1, region: "Sample" });
  const [result, setResult] = useState<any>(null);
  const [loading, setLoading] = useState(false);
  const update = (k: string, v: any) => setForm((s) => ({ ...s, [k]: v }));
  async function checkHealth() { const res = await fetch(`${backendUrl}/api/health`); alert(JSON.stringify(await res.json())); }
  async function predict(e: React.FormEvent) {
    e.preventDefault(); setLoading(true); setResult(null);
    try { const res = await fetch(`${backendUrl}/api/predict`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(form) }); setResult(await res.json()); }
    catch (err) { console.error(err); alert("Prediction failed"); }
    finally { setLoading(false); }
  }
  return (<div style={{ padding: 24, fontFamily: "sans-serif", maxWidth: 720 }}>
    <h2>Rainfall Prediction</h2>
    <button onClick={checkHealth}>Backend health</button>
    <form onSubmit={predict} style={{ marginTop: 16, display: "grid", gap: 12 }}>
      <label>Temperature (°C)<input type="number" step="0.1" value={form.temperature} onChange={(e) => update("temperature", parseFloat(e.target.value))}/></label>
      <label>Humidity (0..1)<input type="number" step="0.01" min="0" max="1" value={form.humidity} onChange={(e) => update("humidity", parseFloat(e.target.value))}/></label>
      <label>Pressure (hPa)<input type="number" step="0.1" value={form.pressure} onChange={(e) => update("pressure", parseFloat(e.target.value))}/></label>
      <label>Wind speed (m/s)<input type="number" step="0.1" value={form.windSpeed} onChange={(e) => update("windSpeed", parseFloat(e.target.value))}/></label>
      <label>Region<input type="text" value={form.region} onChange={(e) => update("region", e.target.value)}/></label>
      <button type="submit" disabled={loading}>{loading ? "Predicting..." : "Predict"}</button>
    </form>
    {result && (<pre style={{ background: "#f5f5f5", padding: 12, marginTop: 16 }}>{JSON.stringify(result, null, 2)}</pre>)}
  </div>);
}
EOF
cat > frontend/Dockerfile << "EOF"
FROM node:18-alpine
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install --no-audit --no-fund
COPY . .
EXPOSE 5173
ENV PORT=5173
CMD ["sh","-lc","npm run dev -- --host 0.0.0.0 --port ${PORT:-5173}"]
EOF

# Minimal README
cat > README.md << "EOF"
Rainfall Prediction System
- backend: Spring Boot REST API (Java 17)
- ml-service: FastAPI prediction service (Python 3.11)
- frontend: Vite + React (TypeScript)
Quickstart: cp .env.example .env && docker compose up --build
EOF

git add -A
git commit -m "chore: scaffold monorepo (backend, ml-service, frontend, compose)" >/dev/null 2>&1 || true
echo "Scaffold complete."