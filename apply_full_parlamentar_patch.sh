#!/bin/bash
set -e

echo "🧩 1/5 • API do Senado (lista e últimas votações)"
mkdir -p src/lib
cat > src/lib/api-senado.ts <<'EOTS'
const BASE = "https://dadosabertos.senado.leg.br/api/v2";

export type Senador = {
  id: string;
  nome: string;
  siglaPartido?: string;
  siglaUf?: string;
  urlFoto?: string;
};

export type VotoSenador = {
  idVotacao: string;
  descricao: string;
  data: string;   // ISO yyyy-mm-dd
  hora?: string;  // hh:mm
  voto: string;   // "Sim", "Não", "Abstenção", etc.
};

// Baixa a lista atual de senadores e filtra por nome (client-side — são só 81)
export async function buscarSenadores(nome?: string): Promise<Senador[]> {
  const url = `${BASE}/senador/lista/atual`;
  const r = await fetch(url, { headers: { accept: "application/json" }});
  if (!r.ok) throw new Error("Falha ao obter senadores");
  const j = await r.json();

  const arr: any[] =
    j?.ListaParlamentarEmExercicio?.Parlamentares?.Parlamentar || [];

  const all: Senador[] = arr.map((p: any) => {
    const dados = p?.IdentificacaoParlamentar || {};
    return {
      id: String(dados?.CodigoParlamentar ?? ""),
      nome: String(dados?.NomeParlamentar ?? "").trim(),
      siglaPartido: dados?.SiglaPartido,
      siglaUf: dados?.UfParlamentar,
      urlFoto: dados?.UrlFotoParlamentar,
    };
  });

  if (!nome) return all;
  const q = nome.toLowerCase().normalize("NFD").replace(/\p{Diacritic}/gu, "");
  return all.filter(s => {
    const n = s.nome.toLowerCase().normalize("NFD").replace(/\p{Diacritic}/gu, "");
    return n.includes(q);
  });
}

// Últimas votações de um senador
// Observação: a API do Senado publica o histórico por senador em
// /senador/{id}/votacoes  (estrutura VotacoesParlamentar). Mapeamos os campos
// mais relevantes; se algum registro vier incompleto, ignoramos com try/catch.
export async function buscarUltimosVotosSenador(id: string, limite = 20): Promise<VotoSenador[]> {
  const url = `${BASE}/senador/${id}/votacoes`;
  const r = await fetch(url, { headers: { accept: "application/json" }});
  if (!r.ok) return [];
  const j = await r.json();

  const lista: any[] =
    j?.VotacoesParlamentar?.Votacoes?.Votacao || [];

  const votos: VotoSenador[] = [];
  for (const v of lista) {
    try {
      // Estruturas possíveis variam um pouco na API do Senado
      const idVot = String(v?.CodigoMateria ?? v?.Codigo ?? v?.CodigoSessao ?? "");
      const descricao =
        String(v?.DescricaoVotacao ?? v?.Descricao ?? v?.Materia?.Descricao ?? "Votação") ;
      // data/hora podem vir em campos distintos
      const data = String(v?.DataSessao ?? v?.Data ?? "").slice(0,10);
      const hora = (v?.Hora??v?.HoraSessao) ? String(v?.Hora??v?.HoraSessao).slice(0,5) : undefined;
      // o voto do parlamentar costuma vir dentro de v.Parlamentar
      const voto =
        String(v?.Parlamentar?.Voto ?? v?.Voto ?? "").trim() || "—";

      if (!idVot || !descricao) continue;

      votos.push({
        idVotacao: idVot,
        descricao,
        data: data || new Date().toISOString().slice(0,10),
        hora,
        voto,
      });
    } catch {}
    if (votos.length >= limite) break;
  }
  return votos;
}
EOTS

echo "🧩 2/5 • Página do SENADOR (detalhe com últimas votações + copiar legenda)"
mkdir -p src/pages
cat > src/pages/Senador.tsx <<'EOTS'
import { useEffect, useState } from "react";
import { Link, useRoute } from "wouter";
import { Card, CardContent, CardHeader, CardTitle, CardDescription, CardFooter } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { ArrowLeft } from "lucide-react";
import { buscarSenadores, buscarUltimosVotosSenador, type Senador, type VotoSenador } from "@/lib/api-senado";
import { legendaParaRedes, explicarProPovao } from "@/lib/povao";

export default function SenadorPage() {
  const [, params] = useRoute("/senador/:id");
  const id = params?.id!;
  const [sen, setSen] = useState<Senador | null>(null);
  const [votos, setVotos] = useState<VotoSenador[]>([]);
  const [loading, setLoading] = useState(true);
  const [copied, setCopied] = useState<string | null>(null);

  useEffect(() => {
    const run = async () => {
      setLoading(true);
      try {
        // como a API não tem endpoint direto p/ um ID único simples, buscamos todos e filtramos:
        const lista = await buscarSenadores();
        const s = lista.find(x => x.id === id) || null;
        setSen(s);
        const vs = await buscarUltimosVotosSenador(id, 20);
        setVotos(vs);
      } finally {
        setLoading(false);
      }
    };
    run();
  }, [id]);

  const copiar = async (v: VotoSenador) => {
    if (!sen) return;
    const texto = legendaParaRedes({
      deputado: sen.nome, // reusa o mesmo formato de legenda
      partido: sen.siglaPartido,
      uf: sen.siglaUf,
      voto: v.voto,
      assunto: v.descricao,
      data: v.data,
    });
    await navigator.clipboard.writeText(texto);
    setCopied(v.idVotacao);
    setTimeout(() => setCopied(null), 1800);
  };

  if (loading) return <div className="container py-6"><Skeleton className="h-64 w-full"/></div>;

  return (
    <div className="container py-6">
      <div className="mb-4">
        <Link href="/"><Button variant="ghost" size="sm"><ArrowLeft className="w-4 h-4 mr-1"/>Voltar</Button></Link>
      </div>

      {sen && (
        <Card className="mb-6">
          <CardHeader className="flex gap-3 items-center">
            {sen.urlFoto && <img src={sen.urlFoto} className="h-16 w-16 rounded-full" alt={sen.nome}/>}
            <div>
              <CardTitle>{sen.nome}</CardTitle>
              <CardDescription>
                <Badge className="mr-2">Sen.</Badge>
                <Badge variant="secondary" className="mr-2">{sen.siglaPartido}</Badge>
                <Badge variant="outline">{sen.siglaUf}</Badge>
              </CardDescription>
            </div>
          </CardHeader>
        </Card>
      )}

      <h2 className="text-xl font-semibold mb-3">Últimas votações</h2>
      {votos.length === 0 && <p>Nenhum registro encontrado agora.</p>}

      {votos.map(v => (
        <Card key={v.idVotacao} className="mb-3">
          <CardHeader className="flex items-center justify-between">
            <CardTitle className="text-base">{v.descricao}</CardTitle>
            <Badge>{v.voto}</Badge>
          </CardHeader>
          <CardContent>
            <p className="text-sm mb-2">{explicarProPovao(v.voto, v.descricao)}</p>
            <Button size="sm" onClick={() => copiar(v)}>
              {copied === v.idVotacao ? "Copiado ✅" : "Copiar legenda 📋"}
            </Button>
          </CardContent>
          <CardFooter>
            <span className="text-xs text-gray-500">{new Date(v.data).toLocaleDateString("pt-BR")}</span>
          </CardFooter>
        </Card>
      ))}
    </div>
  );
}
EOTS

echo "🧩 3/5 • Busca unificada (Deputados + Senadores) com selo 'Dep.' / 'Sen.'"
cat > src/pages/BuscarDeputados.tsx <<'EOTS'
import { useEffect, useState } from "react";
import { Link } from "wouter";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { Search } from "lucide-react";
import { buscarDeputados, type Deputado } from "@/lib/api-camara";
import { buscarSenadores, type Senador } from "@/lib/api-senado";

type Item = {
  id: string;
  nome: string;
  siglaPartido?: string;
  siglaUf?: string;
  urlFoto?: string;
  tipo: "Dep." | "Sen.";
  href: string;
};

export default function BuscarParlamentares() {
  const params = new URLSearchParams(window.location.search);
  const nomeInicial = params.get("nome") || "";

  const [term, setTerm] = useState(nomeInicial);
  const [lista, setLista] = useState<Item[]>([]);
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  async function carregar(q?: string) {
    try {
      setLoading(true);
      setErr(null);
      const [deps, sens] = await Promise.all([
        buscarDeputados(q),
        buscarSenadores(q),
      ]);

      const depItems: Item[] = deps.map((d: Deputado) => ({
        id: String(d.id),
        nome: d.nome,
        siglaPartido: d.siglaPartido,
        siglaUf: d.siglaUf,
        urlFoto: d.urlFoto,
        tipo: "Dep.",
        href: `/deputado/${d.id}`,
      }));

      const senItems: Item[] = sens.map((s: Senador) => ({
        id: String(s.id),
        nome: s.nome,
        siglaPartido: s.siglaPartido,
        siglaUf: s.siglaUf,
        urlFoto: s.urlFoto,
        tipo: "Sen.",
        href: `/senador/${s.id}`,
      }));

      // ordena por nome
      const merged = [...depItems, ...senItems].sort((a,b) => a.nome.localeCompare(b.nome, "pt-BR"));
      setLista(merged);
    } catch (e) {
      console.error(e);
      setErr("Falha na busca.");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    if (nomeInicial) carregar(nomeInicial);
  }, []);

  return (
    <div className="container py-6">
      <h1 className="text-2xl font-bold mb-4">Buscar Parlamentar</h1>
      <div className="flex gap-2 mb-4">
        <Input
          placeholder="Ex: Maria/João..."
          value={term}
          onChange={(e) => setTerm(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && carregar(term)}
        />
        <Button onClick={() => carregar(term)}>
          <Search className="w-4 h-4 mr-1" /> Buscar
        </Button>
      </div>

      {loading && <Skeleton className="h-16 w-full" />}
      {err && <p className="text-red-500">{err}</p>}

      <div className="grid gap-3 md:grid-cols-2">
        {lista.map((p) => (
          <Link key={`${p.tipo}-${p.id}`} href={p.href}>
            <Card className="cursor-pointer hover:bg-gray-50 transition">
              <div className="p-4 flex items-center gap-4">
                {p.urlFoto && <img src={p.urlFoto} alt={p.nome} className="h-12 w-12 rounded-full" />}
                <div>
                  <div className="font-medium">{p.nome}</div>
                  <div className="text-sm text-gray-500 mt-1 flex items-center gap-2">
                    <Badge className="mr-1">{p.tipo}</Badge>
                    {p.siglaPartido && <Badge variant="secondary" className="mr-1">{p.siglaPartido}</Badge>}
                    {p.siglaUf && <Badge variant="outline">{p.siglaUf}</Badge>}
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
EOTS

echo "🧩 4/5 • Rotas: inclui /senador/:id (mantém /deputado/:id e /buscar)"
cat > src/main.tsx <<'EOTS'
import React from "react";
import ReactDOM from "react-dom/client";
import { Route, Switch } from "wouter";

import Home from "@/pages/Home";
import BuscarParlamentares from "@/pages/BuscarDeputados";
import DeputadoPage from "@/pages/Deputado";
import SenadorPage from "@/pages/Senador";

import "./index.css";

function NotFound() {
  return (
    <div className="min-h-screen grid place-items-center">
      <div className="text-center">
        <h1 className="text-5xl font-bold">404</h1>
        <p className="text-gray-500 mt-2">Página não encontrada</p>
        <a href="/" className="text-blue-600 underline mt-4 inline-block">Voltar para a Home</a>
      </div>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <Switch>
      <Route path="/" component={Home} />
      <Route path="/buscar" component={BuscarParlamentares} />
      <Route path="/deputado/:id" component={DeputadoPage} />
      <Route path="/senador/:id" component={SenadorPage} />
      <Route component={NotFound} />
    </Switch>
  </React.StrictMode>
);
EOTS

echo "🧩 5/5 • Garante util 'povao.ts' (se já existir, mantém)"
if [ ! -f src/lib/povao.ts ]; then
cat > src/lib/povao.ts <<'EOTS'
export function explicarProPovao(voto: string, assunto?: string) {
  const tema = assunto ? ` no tema: ${assunto}` : "";
  const v = (voto || "").toLowerCase();

  if (v.includes("sim"))    return `Votou **A FAVOR**${tema}. Ou seja: topou a proposta.`;
  if (v.includes("não") || v.includes("nao"))
                           return `Votou **CONTRA**${tema}. Em resumo: não concordou.`;
  if (v.includes("absten")) return `**SE ABSTEVE**${tema}. Ficou no meio do caminho.`;
  if (v.includes("obstru")) return `Tentou **OBSTRUIR**${tema}. Isso é atrasar/derrubar a pauta.`;
  if (v.includes("art"))    return `Voto técnico por **Artigo Regimental**${tema}. Não é sim/não direto.`;
  return `Registrou voto **${voto}**${tema}.`;
}

export function legendaParaRedes(opts: {
  deputado: string;
  partido?: string;
  uf?: string;
  voto: string;
  assunto?: string;
  data?: string;
}) {
  const dataBr = opts.data ? new Date(opts.data).toLocaleDateString("pt-BR") : "";
  const explic = explicarProPovao(opts.voto, opts.assunto).replace(/\*\*/g, "");
  const linha1 = `🗳️ ${opts.deputado} (${opts.partido || ""}-${opts.uf || ""})`;
  const linha2 = `Como votou: ${opts.voto}`;
  const linha3 = explic;
  const linha4 = dataBr ? `Data: ${dataBr}` : "";
  const tags = `#Transparência #Política #Votações #Brasil`;
  return [linha1, linha2, linha3, linha4, "", tags].filter(Boolean).join("\n");
}
EOTS
fi

echo "✅ Patch aplicado. Rode:  npm run dev"
