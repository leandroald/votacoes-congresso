#!/bin/bash
set -euo pipefail

echo "▶️ Verificando diretório do projeto..."
test -f package.json || { echo "❌ Rode este script na raiz do projeto (onde existe package.json)"; exit 1; }
mkdir -p src/components/ui src/lib src/pages

echo "🧶 Instalando/ajustando deps do Tailwind v4 + ícones (lucide-react)..."
npm i -D @tailwindcss/postcss >/dev/null 2>&1 || true
npm i lucide-react >/dev/null 2>&1 || true

echo "🧼 Removendo pasta física '@' (conflitava com o alias '@') se existir..."
rm -rf @ || true

echo "⚙️ postcss.config.js -> usando '@tailwindcss/postcss'"
cat > postcss.config.js <<'EOF'
export default {
  plugins: {
    '@tailwindcss/postcss': {},
  },
};
EOF

echo "🎨 src/index.css -> base Tailwind v4 + tokens simples usados no app"
cat > src/index.css <<'EOF'
@import "tailwindcss";

@layer base {
  :root {
    --background: 0 0% 100%;
    --destructive: 0 84% 60%;
  }

  .bg-background { background-color: hsl(var(--background)); }
  .text-destructive { color: hsl(var(--destructive)); }
}
EOF

echo "🧭 Atualizando alias '@' no vite.config.ts"
cat > vite.config.ts <<'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { fileURLToPath, URL } from 'node:url'

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
})
EOF

echo "🧠 Ajustando tsconfig.json e tsconfig.app.json para reconhecer '@/*' (editor/TS)"
node - <<'NODE'
const fs = require('fs');
for (const f of ['tsconfig.json','tsconfig.app.json']) {
  if (!fs.existsSync(f)) continue;
  try {
    const json = JSON.parse(fs.readFileSync(f, 'utf8'));
    json.compilerOptions = json.compilerOptions || {};
    json.compilerOptions.baseUrl = json.compilerOptions.baseUrl || '.';
    json.compilerOptions.paths = json.compilerOptions.paths || {};
    json.compilerOptions.paths['@/*'] = ['src/*'];
    fs.writeFileSync(f, JSON.stringify(json, null, 2));
    console.log(`  ✅ Atualizado: ${f}`);
  } catch (e) {
    console.log(`  ⚠️ Não foi possível atualizar ${f} automaticamente: ${e.message}`);
  }
}
NODE

echo "🧩 Criando util de classe (cn) em src/lib/utils.ts"
cat > src/lib/utils.ts <<'EOF'
export function cn(...classes: (string | undefined | false)[]) {
  return classes.filter(Boolean).join(' ');
}
EOF

echo "🧱 Criando componentes mínimos em src/components/ui/*"

cat > src/components/ui/button.tsx <<'EOF'
import * as React from 'react';
import { cn } from '@/lib/utils';

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'default' | 'ghost';
  size?: 'sm' | 'md';
}

export function Button({ className, variant = 'default', size = 'md', ...props }: ButtonProps) {
  const base = 'inline-flex items-center justify-center rounded-md font-medium transition outline-none';
  const variants = {
    default: 'bg-black text-white hover:opacity-90',
    ghost: 'bg-transparent hover:bg-black/5',
  };
  const sizes = {
    sm: 'h-8 px-3 text-sm',
    md: 'h-10 px-4',
  };
  return (
    <button className={cn(base, variants[variant], sizes[size], className)} {...props} />
  );
}
EOF

cat > src/components/ui/input.tsx <<'EOF'
import * as React from 'react';
import { cn } from '@/lib/utils';

export interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {}

export const Input = React.forwardRef<HTMLInputElement, InputProps>(
  ({ className, ...props }, ref) => (
    <input
      ref={ref}
      className={cn(
        'h-10 w-full rounded-md border px-3 text-sm outline-none',
        'border-gray-300 focus:ring-2 focus:ring-black/20',
        className
      )}
      {...props}
    />
  )
);
Input.displayName = 'Input';
EOF

cat > src/components/ui/card.tsx <<'EOF'
import * as React from 'react';
import { cn } from '@/lib/utils';

export function Card({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return <div className={cn('rounded-lg border bg-white shadow', className)} {...props} />;
}

export function CardHeader({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return <div className={cn('p-6', className)} {...props} />;
}

export function CardTitle({ className, ...props }: React.HTMLAttributes<HTMLHeadingElement>) {
  return <h3 className={cn('text-lg font-semibold leading-none', className)} {...props} />;
}

export function CardContent({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return <div className={cn('p-6 pt-0', className)} {...props} />;
}
EOF

cat > src/components/ui/badge.tsx <<'EOF'
import * as React from 'react';
import { cn } from '@/lib/utils';

export interface BadgeProps extends React.HTMLAttributes<HTMLSpanElement> {
  variant?: 'secondary' | 'outline';
}

export function Badge({ className, variant = 'secondary', ...props }: BadgeProps) {
  const variants = {
    secondary: 'bg-gray-100 text-gray-900',
    outline: 'border border-gray-300',
  };
  return (
    <span className={cn('inline-flex items-center rounded px-2 py-0.5 text-xs', variants[variant], className)} {...props} />
  );
}
EOF

cat > src/components/ui/skeleton.tsx <<'EOF'
import * as React from 'react';
import { cn } from '@/lib/utils';

export function Skeleton({ className }: { className?: string }) {
  return <div className={cn('animate-pulse rounded-md bg-gray-200', className)} />;
}
EOF

echo "📄 (Re)criando src/pages/BuscarDeputados.tsx com imports completos (CardHeader/CardTitle)"
cat > src/pages/BuscarDeputados.tsx <<'EOFILE'
import { useState, useEffect } from "react";
import { useLocation, Link } from "wouter";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { Search, ArrowLeft } from "lucide-react";
import { buscarDeputados, type Deputado } from "@/lib/api-camara";

export default function BuscarDeputados() {
  const [location] = useLocation();
  const searchParams = new URLSearchParams(location.split('?')[1]);
  const nomeInicial = searchParams.get('nome') || '';
  const [searchTerm, setSearchTerm] = useState(nomeInicial);
  const [deputados, setDeputados] = useState<Deputado[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    carregarDeputados(nomeInicial);
  }, []);

  const carregarDeputados = async (nome?: string) => {
    setLoading(true);
    setError(null);
    try {
      const dados = await buscarDeputados(nome);
      setDeputados(dados);
    } catch (err) {
      setError('Erro ao carregar deputados');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = () => {
    carregarDeputados(searchTerm);
  };

  return (
    <div className="min-h-screen bg-background">
      <header className="border-b bg-white/80 backdrop-blur-sm sticky top-0 z-50">
        <div className="container py-4">
          <Link href="/">
            <Button variant="ghost" size="sm" className="gap-2">
              <ArrowLeft className="h-4 w-4" />
              Voltar
            </Button>
          </Link>
        </div>
      </header>
      <main className="container py-8">
        <div className="max-w-4xl mx-auto">
          <h1 className="text-3xl font-bold mb-8">Buscar Deputados</h1>
          <Card className="mb-8">
            <div className="p-6">
              <div className="flex gap-2">
                <div className="relative flex-1">
                  <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4" />
                  <Input
                    placeholder="Digite o nome..."
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    className="pl-10"
                  />
                </div>
                <Button onClick={handleSearch}>Buscar</Button>
              </div>
            </div>
          </Card>

          {loading && (
            <div className="grid md:grid-cols-2 gap-4">
              {[1,2,3,4].map(i => (
                <Card key={i}>
                  <div className="p-6"><Skeleton className="h-16 w-full" /></div>
                </Card>
              ))}
            </div>
          )}

          {error && (
            <Card>
              <div className="p-6">
                <p className="text-destructive">{error}</p>
              </div>
            </Card>
          )}

          {!loading && !error && deputados.length === 0 && (
            <Card><div className="p-6 text-center"><p>Nenhum deputado encontrado</p></div></Card>
          )}

          {!loading && !error && deputados.length > 0 && (
            <div className="grid md:grid-cols-2 gap-4">
              {deputados.map(d => (
                <Link key={d.id} href={`/deputado/${d.id}`}>
                  <Card className="hover:shadow-lg transition-shadow cursor-pointer">
                    <div className="p-6 flex gap-4">
                      <img src={d.urlFoto} alt={d.nome} className="h-16 w-16 rounded-full" />
                      <div className="flex-1">
                        <h3 className="font-semibold mb-1">{d.nome}</h3>
                        <div className="flex gap-2">
                          <Badge variant="secondary">{d.siglaPartido}</Badge>
                          <Badge variant="outline">{d.siglaUf}</Badge>
                        </div>
                      </div>
                    </div>
                  </Card>
                </Link>
              ))}
            </div>
          )}
        </div>
      </main>
    </div>
  );
}
EOFILE

echo "✅ Arquivos criados/atualizados."
echo "📦 Dê um 'npm i' se quiser garantir versões."
echo "🚀 Inicie o dev server com: npm run dev"
ls -la src/components/ui | sed 's/^/  /'

