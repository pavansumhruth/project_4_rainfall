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
