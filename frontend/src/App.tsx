import React, { useMemo, useState } from "react";

type PredictResult = { probability: number; label: string; confidence: number } | null;

const backendUrl = import.meta.env.VITE_BACKEND_URL || "http://localhost:8080";

export default function App() {
  const [form, setForm] = useState({
    temperature: 29.4,
    humidity: 0.78,
    pressure: 1006.5,
    windSpeed: 4.1,
    region: "Sample",
  });
  const [result, setResult] = useState<PredictResult>(null);
  const [loading, setLoading] = useState(false);

  const probPct = useMemo(() => (result ? Math.round(result.probability * 100) : 0), [result]);

  const update = (key: string, value: any) => setForm((s) => ({ ...s, [key]: value }));

  async function checkHealth() {
    const res = await fetch(`${backendUrl}/api/health`);
    const j = await res.json();
    alert(JSON.stringify(j, null, 2));
  }

  async function predict(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setLoading(true);
    setResult(null);
    try {
      const res = await fetch(`${backendUrl}/api/predict`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(form),
      });
      const data = await res.json();
      setResult(data);
    } catch (err) {
      console.error(err);
      alert("Prediction failed");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="container">
      <div className="header">
        <div className="title">Rainfall Prediction</div>
        <button className="health-btn" onClick={checkHealth}>Backend health</button>
      </div>

      <div className="grid">
        <div className="card">
          <div className="section-title">Inputs</div>
          <form className="form" onSubmit={predict}>
            <div className="field">
              <label>Temperature (°C)</label>
              <div className="field-row">
                <input className="range" type="range" min={-20} max={50} step={0.1} value={form.temperature} onChange={(e) => update("temperature", parseFloat(e.target.value))} />
                <input className="number" type="number" step={0.1} value={form.temperature} onChange={(e) => update("temperature", parseFloat(e.target.value))} />
              </div>
            </div>

            <div className="field">
              <label>Humidity (0..1)</label>
              <div className="field-row">
                <input className="range" type="range" min={0} max={1} step={0.01} value={form.humidity} onChange={(e) => update("humidity", parseFloat(e.target.value))} />
                <input className="number" type="number" min={0} max={1} step={0.01} value={form.humidity} onChange={(e) => update("humidity", parseFloat(e.target.value))} />
              </div>
            </div>

            <div className="field">
              <label>Pressure (hPa)</label>
              <div className="field-row">
                <input className="range" type="range" min={950} max={1050} step={0.1} value={form.pressure} onChange={(e) => update("pressure", parseFloat(e.target.value))} />
                <input className="number" type="number" step={0.1} value={form.pressure} onChange={(e) => update("pressure", parseFloat(e.target.value))} />
              </div>
            </div>

            <div className="field">
              <label>Wind speed (m/s)</label>
              <div className="field-row">
                <input className="range" type="range" min={0} max={30} step={0.1} value={form.windSpeed} onChange={(e) => update("windSpeed", parseFloat(e.target.value))} />
                <input className="number" type="number" min={0} step={0.1} value={form.windSpeed} onChange={(e) => update("windSpeed", parseFloat(e.target.value))} />
              </div>
            </div>

            <div className="field">
              <label>Region</label>
              <input className="input" type="text" value={form.region} onChange={(e) => update("region", e.target.value)} />
            </div>

            <div className="actions">
              <button className="btn primary" type="submit" disabled={loading}>
                {loading ? "Predicting..." : "Predict"}
              </button>
              <button className="btn" type="button" onClick={() => setResult(null)} disabled={loading}>
                Clear result
              </button>
            </div>
          </form>
        </div>

        <div className="card">
          <div className="section-title">Prediction</div>
          <div className="result">
            <div className="prob-wrap">
              <div className="prob-bar" style={{ width: `${probPct}%` }} />
            </div>
            <div className="prob-info">
              <div>Probability of rain</div>
              <div>{result ? `${probPct}%` : "—"}</div>
            </div>
            {result && (
              <div className="prob-info">
                <div>Label</div>
                <div style={{ color: result.label === "rain" ? "#22d3ee" : "#94a3b8" }}>{result.label}</div>
              </div>
            )}
            {result && (
              <pre className="json">{JSON.stringify(result, null, 2)}</pre>
            )}
          </div>
        </div>
      </div>

      <div className="footer">Tip: tweak sliders to explore the model response.</div>
    </div>
  );
}
