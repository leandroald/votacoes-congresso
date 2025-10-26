/**
 * Client da API da Câmara (v2)
 * Docs: https://dadosabertos.camara.leg.br/swagger/api.html
 */
const BASE = 'https://dadosabertos.camara.leg.br/api/v2';

type Paginacao = { pagina: number; itens: number; totalItens: number; totalPaginas: number };

export type Deputado = {
  id: number;
  nome: string;
  siglaPartido: string;
  siglaUf: string;
  urlFoto: string;
};

export type PerfilDeputado = {
  id: number;
  nomeCivil: string;
  nomeEleitoral: string;
  cpf?: string;
  sexo?: string;
  urlWebsite?: string;
  redeSocial?: string[]; // urls
  ultimoStatus: {
    nome: string;
    siglaPartido: string;
    siglaUf: string;
    urlFoto: string;
    gabinete?: {
      nome?: string;
      email?: string;
      telefone?: string;
      predio?: string;
      sala?: string;
      andar?: string;
    }
  }
};

export type VotacaoDeputado = {
  idVotacao: string;
  data: string; // ISO
  descricao: string;
  orientacaoBancada?: string;
  voto: string; // Sim, Não, Abstenção etc
};

export type ProposicaoResumida = {
  id: number;
  siglaTipo: string;
  numero: string;
  ano: string;
  ementa: string;
  dataApresentacao?: string;
};

async function getJSON<T>(url: string): Promise<T> {
  const r = await fetch(url, { headers: { 'Accept': 'application/json' } });
  if (!r.ok) {
    const txt = await r.text().catch(() => '');
    throw new Error(`HTTP ${r.status} em ${url} ${txt ? '- ' + txt : ''}`);
  }
  return r.json();
}

/** Variante tolerante: retorna null em caso de não-200 */
async function tryJSON<T>(url: string): Promise<T | null> {
  try {
    const r = await fetch(url, { headers: { Accept: 'application/json' } });
    if (!r.ok) return null;
    return r.json();
  } catch {
    return null;
  }
}

/** Busca lista de deputados (nome opcional) */
export async function buscarDeputados(nome?: string): Promise<Deputado[]> {
  const qs = new URLSearchParams();
  if (nome && nome.trim()) qs.set('nome', nome.trim());
  const url = `${BASE}/deputados${qs.toString() ? `?${qs.toString()}` : ''}`;
  const data = await getJSON<{ dados: any[] }>(url);
  return (data.dados || []).map(d => ({
    id: d.id,
    nome: d.nome,
    siglaPartido: d.siglaPartido,
    siglaUf: d.siglaUf,
    urlFoto: d.urlFoto,
  }));
}

/** Perfil completo do deputado */
export async function obterPerfilDeputado(id: number): Promise<PerfilDeputado> {
  const data = await getJSON<{ dados: any }>(`${BASE}/deputados/${id}`);
  return data.dados as PerfilDeputado;
}

/**
 * Últimas votações do deputado (workaround estável):
 * 1) lista votações recentes
 * 2) em cada votação, busca os votos e filtra o do deputado
 * Obs.: Faz em loop sequencial e ignora 400/404 para evitar ruidos
 */
export async function obterVotacoesDeputado(id: number, itens = 15): Promise<VotacaoDeputado[]> {
  // 1) pegar votações recentes (ordem desc por data de registro)
  const baseVot = `${BASE}/votacoes?itens=${itens}&ordem=DESC&ordenarPor=dataHoraRegistro`;
  const votacoes = await getJSON<{ dados: any[] }>(baseVot);

  // 2) para cada votação, pegar os votos e filtrar o do deputado (sequencial/tolerante)
  const results: VotacaoDeputado[] = [];

  for (const v of (votacoes.dados || [])) {
    const votosURL = `${BASE}/votacoes/${v.id}/votos`; // sem itens=1000 para reduzir 400
    const votosResp = await tryJSON<{ dados: any[] }>(votosURL);
    if (!votosResp) continue;

    const meu = (votosResp.dados || []).find((vv) => {
      // defensivo: diferentes chaves possíveis retornadas
      const depId = vv.idDeputado ?? vv.deputado?.id ?? vv.deputado?.idPessoa;
      return Number(depId) === Number(id);
    });

    if (meu) {
      results.push({
        idVotacao: String(v.id),
        data: v.data ?? v.dataHoraRegistro ?? v.dataHora ?? '',
        descricao: v.descricao ?? v.titulo ?? v.tema ?? 'Votação',
        orientacaoBancada: meu.orientacaoBancada ?? meu.orientacao ?? undefined,
        voto: meu.tipoVoto ?? meu.voto ?? '—',
      });
    }
  }

  // Ordena por data desc se tivermos o campo
  results.sort((a, b) => (new Date(b.data).getTime() - new Date(a.data).getTime()));
  return results;
}

/**
 * Proposições do autor: tenta ordenar por dataApresentacao; se 400, usa fallback por id.
 */
export async function obterProposicoesDoAutor(id: number, itens = 10): Promise<ProposicaoResumida[]> {
  async function fetchProps(ordemPor: string) {
    const url = `${BASE}/proposicoes?idDeputadoAutor=${id}&itens=${itens}&ordem=DESC&ordenarPor=${ordemPor}`;
    return getJSON<{ dados: any[] }>(url);
  }

  let data: { dados: any[] };
  try {
    data = await fetchProps('dataApresentacao');
  } catch {
    // fallback seguro quando a API retorna 400 para ordenarPor=dataApresentacao
    data = await fetchProps('id');
  }

  return (data.dados || []).map(p => ({
    id: p.id,
    siglaTipo: p.siglaTipo,
    numero: String(p.numero),
    ano: String(p.ano),
    ementa: p.ementa,
    dataApresentacao: p.dataApresentacao
  }));
}

/**
 * (Opcional) Gera uma legenda “pro povão” para a votação,
 * útil para colar direto nas redes.
 */
export function explicaProPovao(voto: string, descricao?: string): string {
  const v = (voto || '').toLowerCase();
  let verbo: string;
  if (v.includes('sim')) verbo = 'votou SIM';
  else if (v.includes('não') || v.includes('nao')) verbo = 'votou NÃO';
  else if (v.includes('absten')) verbo = 'se ABSTEVE';
  else verbo = `registrou voto: ${voto}`;

  const assunto = descricao ? `— ${descricao}` : '';
  return `${verbo} ${assunto}`.trim();
}

