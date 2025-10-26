import React, { useEffect, useState } from "react";
import { useLocation, Link } from "wouter";

type Parlamentar = {
  id: number;
  nome: string;
  siglaPartido: string;
  siglaUf: string;
  urlFoto: string;
};

export default function BuscarParlamentares() {
  const [location] = useLocation();
  const params = new URLSearchParams(location.split("?")[1] || "");
  const nome = params.get("nome") || "";

  const [items, setItems] = useState<Parlamentar[]>([]);
  const [erro, setErro] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!nome) return;
    const buscar = async () => {
      try {
        setErro(null);
        setLoading(true);
        const res = await fetch(`/api-camara/deputados?nome=${encodeURIComponent(nome)}`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = await res.json();
        setItems(data.dados || []);
      } catch (e: any) {
        console.error(e);
        setErro("Falha na busca");
      } finally {
        setLoading(false);
      }
    };
    buscar();
  }, [nome]);

  return (
    <div style={{ padding: 24 }}>
      <h2 style={{ fontSize: 24, marginBottom: 12 }}>Buscar Parlamentar</h2>

      <input
        defaultValue={nome}
        readOnly
        style={{ padding: "8px 12px", border: "1px solid #ccc", borderRadius: 8, width: "100%", maxWidth: 600 }}
      />

      {loading && <p>Carregando...</p>}
      {erro && <p style={{ color: "#dc2626" }}>{erro}</p>}

      {!loading && !erro && (
        <div style={{ marginTop: 16, display: "grid", gap: 8 }}>
          {items.map((d) => (
            <Link key={d.id} href={`/deputado/${d.id}`}>
              <div
                style={{
                  padding: 12,
                  border: "1px solid #e5e7eb",
                  borderRadius: 8,
                  cursor: "pointer",
                  display: "flex",
                  alignItems: "center",
                  gap: 12,
                }}
              >
                <img src={d.urlFoto} alt={d.nome} style={{ width: 48, height: 48, borderRadius: "50%" }} />
                <div>
                  <div style={{ fontWeight: 600 }}>{d.nome}</div>
                  <div style={{ fontSize: 13, color: "#6b7280" }}>
                    {d.siglaPartido} / {d.siglaUf}
                  </div>
                </div>
              </div>
            </Link>
          ))}
          {!loading && items.length === 0 && <p>Nenhum resultado encontrado.</p>}
        </div>
      )}
    </div>
  );
}
