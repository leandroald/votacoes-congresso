import { useEffect, useState } from "react";
import { Link, useLocation } from "wouter";
import { buscarDeputados, type Deputado } from "@/lib/api-camara";

export default function Buscar() {
  const [loc] = useLocation();
  const params = new URLSearchParams(loc.split("?")[1] || "");
  const [termo, setTermo] = useState(params.get("nome") || "");
  const [lista, setLista] = useState<Deputado[]>([]);
  const [loading, setLoading] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  async function carregar(q?: string) {
    setLoading(true);
    setErro(null);
    try {
      const d = await buscarDeputados(q);
      setLista(d);
    } catch (e: any) {
      setErro(e.message || "Falha na busca.");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { carregar(termo); }, []);

  return (
    <div className="container mx-auto p-6">
      <h1 className="text-2xl font-bold mb-4">Buscar Parlamentar</h1>
      <div className="flex gap-2 mb-6">
        <input
          className="border rounded px-3 py-2 flex-1"
          placeholder="Digite o nome..."
          value={termo}
          onChange={(e) => setTermo(e.target.value)}
        />
        <button
          className="px-4 py-2 rounded bg-black text-white"
          onClick={() => carregar(termo)}
        >
          Buscar
        </button>
      </div>

      {loading && <p>Carregando...</p>}
      {erro && <p className="text-red-600">{erro}</p>}

      {!loading && !erro && lista.length === 0 && <p>Nenhum resultado encontrado.</p>}

      <div className="grid md:grid-cols-2 gap-4">
        {lista.map((d) => (
          <Link key={d.id} href={`/deputado/${d.id}`}>
            <div className="border rounded p-4 flex items-center gap-4 hover:bg-gray-50 cursor-pointer">
              <img src={d.urlFoto} alt={d.nome} className="h-14 w-14 rounded-full" />
              <div className="flex-1">
                <div className="font-semibold">{d.nome}</div>
                <div className="flex gap-2 mt-1">
                  <span className="text-xs border rounded px-2 py-0.5">{d.siglaPartido}</span>
                  <span className="text-xs border rounded px-2 py-0.5">{d.siglaUf}</span>
                </div>
              </div>
            </div>
          </Link>
        ))}
      </div>
    </div>
  );
}
