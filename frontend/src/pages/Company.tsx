import { useEffect, useState } from "react";
import { apiGet } from "../api";
import { useGame } from "../GameContext";

// ---------- TYPES ----------
type Company = {
    id: number;
    name: string;
    cash: number;
};

type InventoryItem = {
    good_id: number;
    quantity: number;
    reserved: number;
    good_name?: string;
};
// ---------------------------

export default function CompanyPage() {
    const [companies, setCompanies] = useState<Company[]>([]);
    const {companyId, setCompanyId } = useGame();
    const [inventory, setInventory] = useState<InventoryItem[]>([]);
    const [error, setError] = useState<string | null>(null);

    // Load companies once
    useEffect(() => {
        apiGet<Company[]>("/companies")
            .then(setCompanies)
            .catch((err) => setError(err.message));
    }, []);

    // Load inventory when company changes
    useEffect(() => {
        if (!companyId) {
            setInventory([]);
            return;
        }

        apiGet<InventoryItem[]>(`/inventories/company/${companyId}`)
            .then(setInventory)
            .catch((err) => setError(err.message));
    }, [companyId]);

    const selectedCompany = companies.find((c) => c.id === companyId);

    return (
        <div>
            <h1>Corporate Dashboard</h1>

            {error && (
                <div style={{ color: "red", marginBottom: 10 }}>
                    {error}
                </div>
            )}

            {/* Company Selector */}
            <div style={{ marginBottom: 20 }}>
                <label>
                    Company:&nbsp;
                    <select
                        value={companyId ?? ""}
                        onChange={(e) =>
                            setCompanyId(
                                e.target.value ? Number(e.target.value) : null
                            )
                        }
                    >
                        <option value="">Select company</option>
                        {companies.map((c) => (
                            <option key={c.id} value={c.id}>
                                {c.name}
                            </option>
                        ))}
                    </select>
                </label>

                {selectedCompany && (
                    <span style={{ marginLeft: 20 }}>
                        💰 Cash: <strong>{selectedCompany.cash}</strong>
                    </span>
                )}
            </div>

            {/* Inventory */}
            {companyId && (
                <>
                    <h2>Inventory</h2>

                    {inventory.length === 0 ? (
                        <p>No inventory</p>
                    ) : (
                        <table border={1} cellPadding={6}>
                            <thead>
                                <tr>
                                    <th>Good</th>
                                    <th>Quantity</th>
                                </tr>
                            </thead>
                            <tbody>
                                {inventory.map((item) => (
                                    <tr key={item.good_id}>
                                        <td>{item.good_name ?? item.good_id}</td>
                                        <td>
                                            {item.quantity - item.reserved} available
                                            {item.reserved > 0 && (
                                                <span style={{ color: "gray" }}>
                                                    {" "}({item.reserved} reserved)
                                                </span>
                                            )}
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    )}
                </>
            )}
        </div>
    );
}
