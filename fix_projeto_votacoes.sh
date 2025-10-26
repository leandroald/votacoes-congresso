#!/bin/bash
set -e

echo "🧩 Corrigindo Home.tsx (fluxo de busca)..."
mkdir -p src/pages
cat > src/pages/Home.tsx <<'EOT'
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { useLocation } from "wouter";

export default function Home() {
  const [term, setTerm] = useState("");
  const [, setLocation] = useLocation();

  const go = () => {
    const q = term.trim();
    setLocation(q ? \`/buscar?nome=\${encodeURIComponent(q)}\` : "/buscar");
  };

  return (
    <main className="container py-8">
      <h1 className="text-3xl font-bold mb-4">Acompanhe como seus representantes votam</h1>
      <Card>
        <CardHeader>
          <CardTitle>Buscar Parlamentar</CardTitle>
          <CardDescription>Digite o nome do deputado</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="flex gap-2">
            <Input
              placeholder="Ex: João Silva..."
              value={term}
              onChange={(e) => setTerm(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && go()}
            />
            <Button onClick={go}>Buscar</Button>
          </div>
        </CardContent>
      </Card>
    </main>
  );
}
EOT

echo "🧩 Corrigindo BuscarDeputados.tsx..."
cat > src/pages/BuscarDeputados.tsx <<'EOT'
import { useState, useEffect } from "react";
import { Link } from "wouter";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { Search } from "lucide-react";
import { buscarDeputados, type Deputado } from "@/lib/api-camara";

export default function BuscarDeputados() {
  const params = new URLSearchParams(window.location.search);
  const nomeInicial = params.get("nome") || "";

  const [searchTerm, setSearchTerm] = useState(nomeInicial);
  const [deputados, setDeputados] = useState<Deputado[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function carregarDeputados(nome?: string) {
    try {
      setLoading(true);
      setError(null);
      const lista = await buscarDeputados(nome);
      setDeputados(lista);
    } catch (e) {
      console.error(e);
      setError("Erro ao buscar deputados.");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    if (nomeInicial) carregarDeputados(nomeInicial);
  }, []);

  return (
    <div className="container py-6">
      <h1 className="text-2xl font-bold mb-4">Buscar Parlamentar</h1>
      <div className="flex gap-2 mb-4">
        <Input
          placeholder="Ex: Maria Silva..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && carregarDeputados(searchTerm)}
        />
        <Button onClick={() => carregarDeputados(searchTerm)}>
          <Search className="w-4 h-4 mr-1" /> Buscar
        </Button>
      </div>

      {loading && <Skeleton className="h-16 w-full" />}
      {error && <p className="text-red-500">{error}</p>}

      <div className="grid gap-3 md:grid-cols-2">
        {deputados.map((d) => (
          <Link key={d.id} href={\`/deputado/\${d.id}\`}>
            <Card className="cursor-pointer hover:bg-gray-50 transition">
              <div className="p-4 flex items-center gap-4">
                <img src={d.urlFoto} alt={d.nome} className="h-12 w-12 rounded-full" />
                <div>
                  <div className="font-medium">{d.nome}</div>
                  <div className="text-sm text-gray-500">
                    <Badge variant="secondary" className="mr-1">{d.siglaPartido}</Badge>
                    <Badge variant="outline">{d.siglaUf}</Badge>
                  </div>
                </div>
              </div>
            </Card>
          </Link>
        ))}
      </div>
    </div>
  );
}
EOT

echo "🧩 Corrigindo Deputado.tsx (últimas votações + botão copiar)..."
cat > src/pages/Deputado.tsx <<'EOT'
import { useEffect, useState } from "react";
import { Link, useRoute } from "wouter";
import { Card, CardContent, CardHeader, CardTitle, CardDescription, CardFooter } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { ArrowLeft } from "lucide-react";
import { buscarDeputado, buscarUltimasVotacoesDoDeputado, type Deputado, type VotoDeputado } from "@/lib/api-camara";
import { explicarProPovao, legendaParaRedes } from "@/lib/povao";

export default function DeputadoPage() {
  const [, params] = useRoute("/deputado/:id");
  const id = params?.id!;
  const [dep, setDep] = useState<Deputado | null>(null);
  const [votos, setVotos] = useState<VotoDeputado[]>([]);
  const [loading, setLoading] = useState(true);
  const [copiedId, setCopiedId] = useState<string | null>(null);

  useEffect(() => {
    const run = async () => {
      const [d, vs] = await Promise.all([
        buscarDeputado(id),
        buscarUltimasVotacoesDoDeputado(id, 20),
      ]);
      setDep(d);
      setVotos(vs);
      setLoading(false);
    };
    run();
  }, [id]);

  const copiarLegenda = async (v: VotoDeputado) => {
    if (!dep) return;
    const texto = legendaParaRedes({
      deputado: dep.nome,
      partido: dep.siglaPartido,
      uf: dep.siglaUf,
      voto: v.voto,
      assunto: v.descricao,
      data: v.data,
    });
    await navigator.clipboard.writeText(texto);
    setCopiedId(v.idVotacao);
    setTimeout(() => setCopiedId(null), 2000);
  };

  if (loading) return <Skeleton className="h-64 w-full" />;

  return (
    <div className="container py-6">
      {dep && (
        <Card className="mb-6">
          <CardHeader className="flex flex-row gap-3 items-center">
            <img src={dep.urlFoto} alt={dep.nome} className="h-16 w-16 rounded-full" />
            <div>
              <CardTitle>{dep.nome}</CardTitle>
              <CardDescription>{dep.siglaPartido}-{dep.siglaUf}</CardDescription>
            </div>
          </CardHeader>
        </Card>
      )}

      {votos.map((v) => (
        <Card key={v.idVotacao} className="mb-3">
          <CardHeader className="flex justify-between items-center">
            <CardTitle className="text-base">{v.descricao}</CardTitle>
            <Badge>{v.voto}</Badge>
          </CardHeader>
          <CardContent>
            <p className="text-sm mb-2">{explicarProPovao(v.voto, v.descricao)}</p>
            <Button size="sm" onClick={() => copiarLegenda(v)}>
              {copiedId === v.idVotacao ? "Copiado ✅" : "Copiar legenda 📋"}
            </Button>
          </CardContent>
          <CardFooter>
            <span className="text-xs text-gray-500">
              {new Date(v.data).toLocaleDateString("pt-BR")}
            </span>
          </CardFooter>
        </Card>
      ))}
    </div>
  );
}
EOT

echo "✅ Tudo atualizado. Execute agora:"
echo "npm run dev"
