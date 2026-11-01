import { useCallback, useEffect, useState } from "react";
import { getTodaysDoses, updateDoseStatus } from "../services/doseApi";
import AddMedication from "./AddMedication";

export default function TodayDoses() {
  const [doses, setDoses] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [updatingId, setUpdatingId] = useState(null);

  const loadDoses = useCallback(async () => {
    try {
      setLoading(true);
      setError("");
      const result = await getTodaysDoses();
      setDoses(Array.isArray(result) ? result : result.doses ?? []);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, []);

  async function handleDoseAction(doseId, status) {
    try {
      setUpdatingId(doseId);
      setError("");
      const extra = {};
      if (status === "snoozed") {
        extra.snoozed_until = new Date(Date.now() + 10 * 60 * 1000).toISOString();
      }
      await updateDoseStatus(doseId, status, extra);
      await loadDoses();
    } catch (err) {
      setError(err.message);
    } finally {
      setUpdatingId(null);
    }
  }

  useEffect(() => {
    loadDoses();
  }, [loadDoses]);

  // Keep both actions in AddMedication's toolbar so the form can expand
  // below the entire row instead of squeezing into a narrow flex column.
  return (
    <section className="mt-today-doses">
      <AddMedication onCreated={loadDoses} onRefresh={loadDoses} />

      {error && <p role="alert" className="mt-error">{error}</p>}
      {loading && <p>Loading today's doses...</p>}
      {!loading && !error && doses.length === 0 && (
        <p>No scheduled doses found for today.</p>
      )}

      {!loading && doses.map((dose) => (
        <article key={dose.id} className="mt-today-dose-card">
          <strong>
            {dose.medications?.name || dose.medication?.name || "Medication"}
          </strong>
          <p>
            Scheduled:{" "}
            {new Date(dose.scheduled_time).toLocaleTimeString([], {
              hour: "2-digit",
              minute: "2-digit",
            })}
          </p>
          <p>Status: {dose.status}</p>
          {["pending", "snoozed"].includes(dose.status) && (
            <div className="mt-dose-actions">
              <button
                className="dashboard-button mt-small-button"
                type="button"
                disabled={updatingId !== null}
                onClick={() => handleDoseAction(dose.id, "taken")}
              >
                Taken
              </button>
              <button
                className="dashboard-button mt-small-button"
                type="button"
                disabled={updatingId !== null}
                onClick={() => handleDoseAction(dose.id, "skipped")}
              >
                Skip
              </button>
              <button
                className="dashboard-button mt-small-button"
                type="button"
                disabled={updatingId !== null}
                onClick={() => handleDoseAction(dose.id, "snoozed")}
              >
                Snooze 10 min
              </button>
            </div>
          )}
        </article>
      ))}
    </section>
  );
}
