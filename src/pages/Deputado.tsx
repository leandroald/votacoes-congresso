import { useEffect, useState } from "react";
import { Link, useRoute } from "wouter";
import {
  obterPerfilDeputado,
  obterVotacoesDeputado,
  obterProposicoesDoAutor,
  type PerfilDeputado,
  type VotacaoDeputado,
  type ProposicaoResumida
} from "@/lib/api-camara";

export default function DeputadoPage() {
  const [, params] = useRoute("/deputado/:id");
  const id = Number(params?.id);
  const [perfil, setPerfil] = useState<PerfilDeputado | null>(null);
  const [votos, setVotos] = useState<VotacaoDeputado[]>([]);
  const [props, setProps] = useState<ProposicaoResumida[]>([]);
  const [loading, setLoading] = useState(true);
  const [erro, setErro] = useState<string | null>(null);

  useEffect(() => {
    async function carregarTudo() {
      setLoading(true);
      setErro(null);
      try {
        const [p, v, pr] = await Promise.all([
          obterPerfilDeputado(id),
          obterVotacoesDeputado(id, 20),
          obterProposicoesDoAutor(id, 10)
        ]);
        setPerfil(p);
        setVotos(v);
        setProps(pr);
      } catch (e: any) {
        setErro(e.message || "Falha ao carregar dados do parlamentar.");
      } finally {
        setLoading(false);
      }
    }
    if (id) carregarTudo();
  }, [id]);

  if (loading) return <div className="p-6">Carregando...</div>;
  if (erro) return (
    <div className="p-6">
      <Link href="/buscar"><span className="underline">← Voltar</span></Link>
      <p className="text-red-600 mt-4">{erro || "Falha ao carregar dados do parlamentar."}</p>
    </div>
  );
  if (!perfil) return null;

  return (
    <div className="container mx-auto p-6">
      <Link href="/buscar"><span className="underline">← Voltar</span></Link>

      <div className="flex items-center gap-4 mt-4">
        <img src={perfil.ultimoStatus.urlFoto} className="h-20 w-20 rounded-full" />
        <div>
          <h1 className="text-2xl font-bold">{perfil.ultimoStatus.nome}</h1>
          <div className="text-sm text-gray-600 mt-1">
            {perfil.ultimoStatus.siglaPartido} • {perfil.ultimoStatus.siglaUf}
          </div>
          {perfil.ultimoStatus.gabinete?.email && (
            <div className="text-sm mt-1">{perfil.ultimoStatus.gabinete.email}</div>
          )}
        </div>
      </div>

      {/* Votações */}
      <section className="mt-8">
        <h2 className="text-xl font-semibold mb-3">Últimas votações</h2>
        {votos.length === 0 && <p>Nenhuma votação recente encontrada.</p>}
        <div className="space-y-3">
          {votos.map((v) => (
            <div key={v.idVotacao} className="border rounded p-3">
              <div className="text-sm text-gray-500">{new Date(v.data).toLocaleString('pt-BR')}</div>
              <div className="font-medium mt-1">{v.descricao}</div>
              <div className="mt-1 text-sm">
                Voto: <b>{v.voto}</b>
                {v.orientacaoBancada ? <> • Orientação: <i>{v.orientacaoBancada}</i></> : null}
              </div>
              {/* Lugar para “explicar pro povão” (placeholder).
                 Quando você plugar sua IA, use v.descricao + v.voto e gere o resumo aqui. */}
              <div className="text-sm mt-2 italic text-gray-700">
                Explicação (resuminho): esse voto significa que o deputado se posicionou dessa forma no tema acima.
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* Proposições do autor */}
      <section className="mt-8">
        <h2 className="text-xl font-semibold mb-3">Proposições apresentadas</h2>
        {props.length === 0 && <p>Nenhuma proposição recente encontrada.</p>}
        <div className="space-y-3">
          {props.map((p) => (
            <div key={p.id} className="border rounded p-3">
              <div className="text-sm text-gray-500">
                {p.siglaTipo} {p.numero}/{p.ano}
                {p.dataApresentacao ? ` • ${new Date(p.dataApresentacao).toLocaleDateString('pt-BR')}` : ''}
              </div>
              <div className="mt-1">{p.ementa}</div>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}
