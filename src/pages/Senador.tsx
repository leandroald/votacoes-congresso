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
