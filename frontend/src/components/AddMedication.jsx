import { useState } from "react";
import { supabase } from "../lib/supabaseClient";

const API_URL = "http://localhost:3000/api/medications";

function localDate(offsetDays = 0) {
  const date = new Date();
  date.setDate(date.getDate() + offsetDays);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

async function authorizedRequest(url, options = {}) {
  const { data, error } = await supabase.auth.getSession();
  if (error) throw error;
  const token = data?.session?.access_token;
  if (!token) throw new Error("Session expired. Please log in again.");

  const response = await fetch(url, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
      ...(options.headers ?? {}),
    },
  });
  const result = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(result.error || `Request failed (${response.status})`);
  }
  return result;
}

export default function AddMedication({ onCreated, onRefresh }) {
  const [open, setOpen] = useState(false);
  const [name, setName] = useState("");
  const [dosage, setDosage] = useState("1 tablet");
  const [time, setTime] = useState("20:00");
  const [startDate, setStartDate] = useState(localDate());
  const [pills, setPills] = useState("20");
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");

  async function handleSubmit(event) {
    event.preventDefault();
    if (saving) return;
    setSaving(true);
    setMessage("");

    try {
      const end = new Date(`${startDate}T12:00:00`);
      end.setDate(end.getDate() + 7);
      const endDate = [
        end.getFullYear(),
        String(end.getMonth() + 1).padStart(2, "0"),
        String(end.getDate()).padStart(2, "0"),
      ].join("-");

      await authorizedRequest(API_URL, {
        method: "POST",
        body: JSON.stringify({
          name: name.trim(),
          dosage: dosage.trim(),
          frequency: "daily",
          times: [time],
          start_date: startDate,
          end_date: endDate,
          pills_remaining: Number(pills),
          refill_threshold: 5,
          active: true,
        }),
      });

      setMessage("Medication added successfully!");
      setName("");
      setOpen(false);
      if (typeof onCreated === "function") await onCreated();
    } catch (error) {
      setMessage(`Error: ${error.message}`);
    } finally {
      setSaving(false);
    }
  }

  const field = {
    display: "block",
    width: "100%",
    boxSizing: "border-box",
    padding: "10px 12px",
    border: "1px solid #cbd5e1",
    borderRadius: 8,
    fontSize: 15,
    marginTop: 5,
  };
  const button = {
    background: "#2563eb",
    color: "white",
    border: 0,
    borderRadius: 8,
    padding: "10px 16px",
    cursor: "pointer",
  };

  return (
    <div style={{ marginBottom: 16 }}>
      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          gap: 12,
          flexWrap: "wrap",
        }}
      >
        <button
          type="button"
          className="dashboard-button dashboard-button-secondary mt-small-button"
          onClick={onRefresh}
          disabled={saving}
        >
          Refresh doses
        </button>
        <button
          type="button"
          style={button}
          onClick={() => {
            setOpen((value) => !value);
            setMessage("");
          }}
        >
          {open ? "Cancel" : "+ Add Medication"}
        </button>
      </div>

      {open && (
        <form
          onSubmit={handleSubmit}
          style={{
            display: "grid",
            gap: 12,
            marginTop: 16,
            padding: 20,
            border: "1px solid #dbe4f0",
            borderRadius: 14,
            background: "white",
            color: "#172033",
          }}
        >
          <label>
            Medication name
            <input style={field} value={name} onChange={(e) => setName(e.target.value)} required placeholder="Demo Medicine E" />
          </label>
          <label>
            Dosage
            <input style={field} value={dosage} onChange={(e) => setDosage(e.target.value)} required placeholder="1 tablet" />
          </label>
          <label>
            Daily reminder time
            <input style={field} type="time" value={time} onChange={(e) => setTime(e.target.value)} required />
          </label>
          <label>
            Start date
            <input style={field} type="date" value={startDate} onChange={(e) => setStartDate(e.target.value)} required />
          </label>
          <label>
            Number of pills
            <input style={field} type="number" min="0" step="1" value={pills} onChange={(e) => setPills(e.target.value)} required />
          </label>
          <button type="submit" disabled={saving} style={{ ...button, opacity: saving ? 0.6 : 1 }}>
            {saving ? "Saving..." : "Save Medication"}
          </button>
        </form>
      )}

      {message && (
        <p role="status" style={{ color: message.startsWith("Error:") ? "#b91c1c" : "#15803d" }}>
          {message}
        </p>
      )}
    </div>
  );
}
