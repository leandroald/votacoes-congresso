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
