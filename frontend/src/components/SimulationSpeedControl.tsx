import { useEffect, useState } from "react";
import { apiGet, apiPost } from "../api";

export default function SimulationSpeedControl() {
    const [speed, setSpeed] = useState<number>(1);

    const loadSpeed = async () => {
        const data = await apiGet<{ speed_multiplier: number }>(
            "/simulation/speed"
        );
        setSpeed(data.speed_multiplier);
    };

    const updateSpeed = async (value: number) => {
        await apiPost(`/simulation/speed?multiplier=${value}`, {});
        setSpeed(value);
    };

    useEffect(() => {
        loadSpeed();
    }, []);

    return (
        <div
            style={{
                position: "fixed",
                bottom: 10,
                right: 10,
                padding: 10,
                background: "#111",
                color: "#0f0",
                border: "1px solid #0f0",
                fontFamily: "monospace",
                zIndex: 9999,
            }}
        >
            <div><strong>⏱ SIM SPEED</strong></div>
            <div>{speed}×</div>

            <div style={{ display: "flex", gap: 5, marginTop: 5 }}>
                {[0.25, 1, 5, 10, 60].map((v) => (
                    <button
                        key={v}
                        onClick={() => updateSpeed(v)}
                        style={{
                            background: v === speed ? "#0f0" : "#222",
                            color: v === speed ? "#000" : "#0f0",
                            border: "1px solid #0f0",
                            cursor: "pointer",
                        }}
                    >
                        {v}×
                    </button>
                ))}
            </div>
        </div>
    );
}
