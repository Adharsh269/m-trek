import { useState } from "react";
import TodayDoses from "./TodayDoses";
import "../styles/dashboard.css";

export default function Dashboard({ session, onLogout, loading }) {
  const [view, setView] = useState("overview");

  return (
    <main className="mt-shell dashboard-page">
      <aside className="mt-sidebar">
        <div className="mt-brand">
          <span className="mt-brand-symbol">✚</span>
          <span>MedicTrack</span>
        </div>
        <div className="mt-sidebar-caption">PATIENT WORKSPACE</div>

        <nav className="mt-nav" aria-label="Dashboard sections">
          <button
            className={`mt-nav-button ${view === "overview" ? "is-active" : ""}`}
            type="button"
            onClick={() => setView("overview")}
          >
            ▦ Overview
          </button>
          <button
            className={`mt-nav-button ${view === "doses" ? "is-active" : ""}`}
            type="button"
            onClick={() => setView("doses")}
          >
            ✚ Today's doses
          </button>
        </nav>

        <div className="mt-sidebar-bottom">
          <div className="mt-account">{session.user.email}</div>
          <button className="mt-logout" type="button" onClick={onLogout} disabled={loading}>
            Log out
          </button>
        </div>
      </aside>

      <div className="mt-main">
        <header className="mt-topbar">
          <div>
            <div className="mt-eyebrow">Patient dashboard</div>
            <h1 style={{ color: "#172033" }}>
              {view === "overview" ? "Overview" : "Today's doses"}
            </h1>
          </div>
          <span className="mt-topbar-user">{session.user.email}</span>
        </header>

        {view === "overview" && (
          <>
            <section className="dashboard-card mt-panel">
              <h2>Welcome to MedicTrack</h2>
              <p className="mt-muted">Review your medication schedule and track your doses from one place.</p>
              <div className="mt-quick-actions">
                <button className="dashboard-button" type="button" onClick={() => setView("doses")}>View today's doses</button>
              </div>
            </section>
            <section className="dashboard-card mt-panel">
              <h2>Today's medications</h2>
              <TodayDoses />
            </section>
          </>
        )}

        {view === "doses" && (
          <section className="dashboard-card mt-panel">
            <h2>Today's medications</h2>
            <TodayDoses />
          </section>
        )}
      </div>
    </main>
  );
}
