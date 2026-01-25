import { useEffect, useState } from "react";
import { apiGet, apiPost } from "../api";
import { useGame } from "../GameContext";

type Deposit = {
    good_id: number;
    good_name: string;
    remaining_amount: number;
};

type ExtractionSite = {
    id: number;
    company_id: number;
    company_name: string;
    good_id: number;
    good_name: string;
    rate_per_hour: number;
    active: boolean;
};

type Location = {
    id: number;
    name: string;
    x: number;
    y: number;
    deposits: Deposit[];
    extraction_sites: ExtractionSite[];
    claimed_by_company_id?: number | null;
};

export default function MapPage() {
    const { companyId } = useGame();

    const [locations, setLocations] = useState<Location[]>([]);
    const [selected, setSelected] = useState<Location | null>(null);
    const [error, setError] = useState<string | null>(null);

    const loadMap = async () => {
        try {
            const data = await apiGet<{ locations: Location[] }>("/map");
            setLocations(data.locations);
            return data.locations;
        } catch (e: any) {
            setError(e.message);
        }
    };

    useEffect(() => {
        loadMap();
    }, []);

    const claimLocation = async (locationId: number) => {
        if (!companyId) return;

        try {
            await apiPost(
                `/locations/${locationId}/claim?company_id=${companyId}`,
                {}
            );
            const updatedLocations = await loadMap();

            const updated = updatedLocations.find(l => l.id === locationId);
            if (updated) {
                setSelected(updated);
            }
        } catch (e: any) {
            setError(e.message);
        }
    };

    const buildExtractor = async (locationId: number, goodId: number) => {
        if (!companyId) return;

        await apiPost(`/extraction-sites/?company_id=${companyId}`, {
            location_id: locationId,
            good_id: goodId,
            rate_per_hour: 5,
        });

        const updatedLocations = await loadMap();

        const updated = updatedLocations.find(l => l.id === locationId);
        if (updated) {
            setSelected(updated);
        }
    };


    return (
        <div style={{ display: "flex", gap: 30 }}>
            <div>
                <h1>Exploration</h1>
                {error && <div style={{ color: "red" }}>{error}</div>}

                <svg width={600} height={600} style={{ border: "1px solid #444" }}>
                    {locations.map((l) => (
                        <circle
                            key={l.id}
                            cx={l.x / 2}
                            cy={l.y / 2}
                            r={6}
                            fill={
                                l.claimed_by_company_id
                                    ? l.claimed_by_company_id === companyId
                                        ? "green"
                                        : "red"
                                    : "blue"
                            }
                            onClick={() => setSelected(l)}
                            style={{ cursor: "pointer" }}
                        />
                    ))}
                </svg>
            </div>

            {selected && (
                <div style={{ width: 400 }}>
                    <h2>{selected.name}</h2>
                    <p>
                        Coordinates: ({Math.round(selected.x)}, {Math.round(selected.y)})
                    </p>

                    {/* CLAIM */}
                    {!selected.claimed_by_company_id && companyId && (
                        <button onClick={() => claimLocation(selected.id)}>
                            Claim Location
                        </button>
                    )}

                    {selected.claimed_by_company_id &&
                        selected.claimed_by_company_id !== companyId && (
                            <p style={{ color: "red" }}>Owned by another company</p>
                        )}

                    {/* DEPOSITS */}
                    <h3>Deposits</h3>
                    <ul>
                        {selected.deposits.map((d) => (
                            <li key={d.good_id}>
                                {d.good_name} – {d.remaining_amount}

                                {/* BUILD EXTRACTOR */}
                                {selected.claimed_by_company_id === companyId &&
                                    !selected.extraction_sites.find(
                                        (s) => s.good_id === d.good_id
                                    ) && (
                                        <button
                                            style={{ marginLeft: 10 }}
                                            onClick={() =>
                                                buildExtractor(selected.id, d.good_id)
                                            }
                                        >
                                            Build extractor
                                        </button>
                                    )}
                            </li>
                        ))}
                    </ul>

                    {/* EXISTING SITES */}
                    <h3>Extraction Sites</h3>
                    {selected.extraction_sites.length === 0 ? (
                        <p>None</p>
                    ) : (
                        <ul>
                            {selected.extraction_sites.map((s) => (
                                <li key={s.id}>
                                    {s.good_name} – {s.rate_per_hour}/h (
                                    {s.active ? "active" : "inactive"})
                                </li>
                            ))}
                        </ul>
                    )}
                </div>
            )}
        </div>
    );
}
