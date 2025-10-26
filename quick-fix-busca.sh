#!/usr/bin/env bash
set -euo pipefail

echo "🧹 Ajustando lib da Câmara (fetch direto, sem proxy/CORS local)..."
mkdir -p src/lib
cat > src/lib/api-camara.ts <<'TS'
export type Deputado = {
  id: number
  nome: string
  siglaPartido: string
  siglaUf: string
  urlFoto: string
}

export type DetalheDeputado = Deputado & {
  uri: string
  email: string | null
  idLegislatura: number
}

export type VotoDeputado = {
  idVotacao: string
  data: string
  descricao: string
  voto: string
}

const CAMARA = 'https://dadosabertos.camara.leg.br/api/v2'

async function getJSON<T>(url: string): Promise<T> {
  const r = await fetch(url, { headers: { Accept: 'application/json' } })
  if (!r.ok) throw new Error(`HTTP ${r.status} em ${url}`)
  return r.json() as Promise<T>
}

export async function buscarDeputados(nome?: string): Promise<Deputado[]> {
  const u = new URL(`${CAMARA}/deputados`)
  if (nome && nome.trim()) u.searchParams.set('nome', nome.trim())
  u.searchParams.set('itens', '50')
  u.searchParams.set('ordem', 'ASC')
  u.searchParams.set('ordenarPor', 'nome')

  type Resp = { dados: any[] }
  const j = await getJSON<Resp>(u.toString())
  return (j.dados || []).map((d) => ({
    id: d.id,
    nome: d.nome,
    siglaPartido: d.siglaPartido,
    siglaUf: d.siglaUf,
    urlFoto: d.urlFoto,
  }))
}

export async function obterDeputado(id: number): Promise<DetalheDeputado> {
  type Resp = { dados: any }
  const j = await getJSON<Resp>(`${CAMARA}/deputados/${id}`)
  const d = j.dados
  return {
    id: d.id,
    nome: d.nome,
    siglaPartido: d.ultimoStatus?.siglaPartido ?? d.siglaPartido,
    siglaUf: d.ultimoStatus?.siglaUf ?? d.siglaUf,
    urlFoto: d.ultimoStatus?.urlFoto ?? d.urlFoto,
    idLegislatura: d.idLegislatura ?? d.ultimoStatus?.idLegislatura ?? 0,
    email: d.ultimoStatus?.gabinete?.email ?? d.email ?? null,
    uri: d.uri,
  }
}

/**
 * A API oficial retorna as votações de um deputado em:
 *  GET /deputados/{id}/votacoes?itens=50
 * Campos variam um pouco conforme a sessão → normalizamos.
 */
export async function votacoesDoDeputado(id: number, itens = 30): Promise<VotoDeputado[]> {
  type Resp = { dados: any[] }
  const url = `${CAMARA}/deputados/${id}/votacoes?itens=${itens}`
  const j = await getJSON<Resp>(url)
  return (j.dados || []).map((v) => ({
    idVotacao: String(v.idVotacao ?? v.id ?? ''),
    data: v.data ?? v.dataHora ?? v.dataHoraRegistro ?? '',
    descricao:
      v.descricao ??
      v.descricaoVotacao ??
      v.titulo ??
      v.proposicaoObjeto ??
      'Votação do Plenário',
    voto: v.voto ?? v.tipoVoto ?? v.opcaoVoto ?? v.orientacao ?? '—',
  }))
}

/** Explica o voto em “linguajar do povão” para redes sociais (sem IA paga). */
export function explicarProPovao(voto: string, assunto: string): string {
  const v = (voto || '').toUpperCase()
  const base = assunto.replace(/\s+/g, ' ').trim()
  const assuntoLimpo = base.length > 140 ? base.slice(0, 137) + '…' : base

  if (v === 'SIM' || v === 'S') return `Votou **SIM**. Na prática: topou a proposta ➜ ${assuntoLimpo}.`
  if (v === 'NÃO' || v === 'NAO' || v === 'N') return `Votou **NÃO**. Na prática: foi contra a proposta ➜ ${assuntoLimpo}.`
  if (v === 'OBSTRUÇÃO' || v === 'OBSTRUCAO') return `**Obstruiu**. Tradução: fez corpo mole pra atrasar a votação ➜ ${assuntoLimpo}.`
  if (v === 'ABSTENÇÃO' || v === 'ABSTENCAO') return `**Absteve-se**. Ficou em cima do muro nessa ➜ ${assuntoLimpo}.`
  return `Voto: **${voto || '—'}** ➜ ${assuntoLimpo}.`
}
TS

echo "🧩 Recriando página de BUSCA (lê querystring ?nome= e busca direto na API)..."
mkdir -p src/pages
cat > src/pages/Buscar.tsx <<'TSX'
import { useEffect, useState } from 'react'
import { Link, useLocation } from 'wouter'
import { buscarDeputados, type Deputado } from '@/lib/api-camara'

export default function Buscar() {
  const [loc, setLoc] = useLocation()
  const params = new URLSearchParams(loc.split('?')[1] || '')
  const nomeInicial = params.get('nome') || ''

  const [term, setTerm] = useState(nomeInicial)
  const [items, setItems] = useState<Deputado[]>([])
  const [loading, setLoading] = useState(false)
  const [err, setErr] = useState<string | null>(null)

  useEffect(() => {
    if (nomeInicial) doSearch(nomeInicial)
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const doSearch = async (q: string) => {
    setLoading(true)
    setErr(null)
    try {
      const data = await buscarDeputados(q)
      setItems(data)
    } catch (e: any) {
      console.error(e)
      setErr('Falha na busca.')
      setItems([])
    } finally {
      setLoading(false)
    }
  }

  const submit = () => {
    const q = term.trim()
    setLoc(q ? `/buscar?nome=${encodeURIComponent(q)}` : '/buscar')
    doSearch(q)
  }

  return (
    <div className="container mx-auto p-6">
      <h1 className="text-2xl font-bold mb-4">Buscar Parlamentar</h1>

      <div className="flex gap-2 mb-6">
        <input
          value={term}
          onChange={(e) => setTerm(e.target.value)}
          placeholder="Digite o nome..."
          className="border rounded px-3 py-2 flex-1"
        />
        <button onClick={submit} className="px-4 py-2 rounded bg-black text-white">Buscar</button>
      </div>

      {loading && <p>Carregando…</p>}
      {err && <p className="text-red-600">{err}</p>}

      {!loading && !err && items.length === 0 && <p>Nenhum resultado encontrado.</p>}

      <div className="grid md:grid-cols-2 gap-3">
        {items.map((d) => (
          <Link key={d.id} href={`/deputado/${d.id}`}>
            <div className="border rounded p-4 flex gap-4 items-center cursor-pointer hover:bg-gray-50">
              <img src={d.urlFoto} alt={d.nome} className="h-12 w-12 rounded-full" />
              <div className="flex-1">
                <div className="font-medium">{d.nome}</div>
                <div className="text-sm text-gray-600 flex gap-2">
                  <span className="px-2 py-0.5 border rounded">{d.siglaPartido}</span>
                  <span className="px-2 py-0.5 border rounded">{d.siglaUf}</span>
                </div>
              </div>
            </div>
          </Link>
        ))}
      </div>
    </div>
  )
}
TSX

echo "🧩 Recriando página do DEPUTADO (dados + últimas votações + legenda pra redes)…"
cat > src/pages/Deputado.tsx <<'TSX'
import { useEffect, useState } from 'react'
import { Link, useRoute } from 'wouter'
import { obterDeputado, votacoesDoDeputado, explicarProPovao } from '@/lib/api-camara'

export default function DeputadoPage() {
  const [, params] = useRoute('/deputado/:id')
  const id = Number(params?.id)

  const [loading, setLoading] = useState(true)
  const [err, setErr] = useState<string | null>(null)
  const [deputado, setDeputado] = useState<any>(null)
  const [votos, setVotos] = useState<any[]>([])

  useEffect(() => {
    if (!id) return
    ;(async () => {
      setLoading(true)
      setErr(null)
      try {
        const [d, vs] = await Promise.all([obterDeputado(id), votacoesDoDeputado(id, 20)])
        setDeputado(d)
        setVotos(vs)
      } catch (e: any) {
        console.error(e)
        setErr('Falha ao carregar dados do parlamentar.')
      } finally {
        setLoading(false)
      }
    })()
  }, [id])

  return (
    <div className="container mx-auto p-6">
      <Link href="/buscar"><a className="text-sm">&larr; Voltar</a></Link>
      <h1 className="text-2xl font-bold mt-2">Perfil do Parlamentar</h1>

      {loading && <p>Carregando…</p>}
      {err && <p className="text-red-600">{err}</p>}

      {deputado && (
        <div className="border rounded p-4 my-4 flex gap-4 items-center">
          <img src={deputado.urlFoto} className="h-16 w-16 rounded-full" />
          <div>
            <div className="font-semibold text-lg">{deputado.nome}</div>
            <div className="text-sm text-gray-600 flex gap-2">
              <span className="px-2 py-0.5 border rounded">{deputado.siglaPartido}</span>
              <span className="px-2 py-0.5 border rounded">{deputado.siglaUf}</span>
            </div>
            {deputado.email && <div className="text-sm text-gray-600">{deputado.email}</div>}
          </div>
        </div>
      )}

      {!loading && votos.length > 0 && (
        <div className="space-y-3">
          <h2 className="font-semibold text-lg">Últimas votações</h2>
          {votos.map((v) => (
            <div key={v.idVotacao} className="border rounded p-3">
              <div className="text-sm text-gray-500">{new Date(v.data).toLocaleString()}</div>
              <div className="font-medium">{v.descricao}</div>
              <div className="mt-1">Voto: <b>{v.voto}</b></div>

              <div className="mt-2 text-sm leading-relaxed">
                {explicarProPovao(v.voto, v.descricao)}
              </div>

              <button
                className="mt-2 text-sm px-3 py-1 rounded border"
                onClick={() => {
                  const legenda =
                    `🧭 ${deputado?.nome} (${deputado?.siglaPartido}-${deputado?.siglaUf})
${explicarProPovao(v.voto, v.descricao)}
#Votações #Transparência`
                  navigator.clipboard.writeText(legenda)
                }}
              >
                Copiar legenda 📋
              </button>
            </div>
          ))}
        </div>
      )}

      {!loading && votos.length === 0 && !err && <p>Nenhuma votação encontrada.</p>}
    </div>
  )
}
TSX

echo "🧭 Ajustando Home pra empurrar direto pra /buscar?nome=…"
cat > src/pages/Home.tsx <<'TSX'
import { useState } from 'react'
import { useLocation, Link } from 'wouter'

export default function Home() {
  const [, setLoc] = useLocation()
  const [term, setTerm] = useState('')

  const go = () => {
    const q = term.trim()
    setLoc(q ? `/buscar?nome=${encodeURIComponent(q)}` : '/buscar')
  }

  return (
    <div className="container mx-auto p-6">
      <div className="text-sm mb-2"><Link href="/buscar">(demonstrar busca)</Link></div>
      <h1 className="text-3xl font-bold mb-6">Votações do Congresso</h1>
      <div className="flex gap-2 max-w-2xl">
        <input
          value={term}
          onChange={(e) => setTerm(e.target.value)}
          placeholder="Ex.: João Silva"
          className="border rounded px-3 py-2 flex-1"
        />
        <button onClick={go} className="px-4 py-2 rounded bg-black text-white">Buscar</button>
      </div>
    </div>
  )
}
TSX

echo "🛣️ Garantindo rotas principais em src/main.tsx…"
cat > src/main.tsx <<'TSX'
import React from 'react'
import ReactDOM from 'react-dom/client'
import { Route, Switch } from 'wouter'
import Home from '@/pages/Home'
import Buscar from '@/pages/Buscar'
import DeputadoPage from '@/pages/Deputado'

import './index.css'

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <Switch>
      <Route path="/" component={Home} />
      <Route path="/buscar" component={Buscar} />
      <Route path="/deputado/:id" component={DeputadoPage} />
      <Route>404 - Página não encontrada</Route>
    </Switch>
  </React.StrictMode>
)
TSX

echo "✅ Pronto. Dica: npm run dev  — e teste /buscar?nome=joao"
