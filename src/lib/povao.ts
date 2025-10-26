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
  data?: string; // ISO
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
