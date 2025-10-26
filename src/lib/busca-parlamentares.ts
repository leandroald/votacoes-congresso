import type { Deputado } from './api-camara';
import type { Senador } from './api-senado';
import { buscarDeputados } from './api-camara';
import { buscarSenadores } from './api-senado';

export type Parlamentar = (Deputado | Senador) & { cargo: 'Deputado' | 'Senador' };

export async function buscarParlamentares(nome?: string): Promise<Parlamentar[]> {
  const [deps, sens] = await Promise.all([
    buscarDeputados(nome),
    buscarSenadores(nome),
  ]);

  return [
    ...deps.map((d) => ({ ...d, cargo: 'Deputado' as const })),
    ...sens.map((s) => ({ ...s, cargo: 'Senador' as const })),
  ];
}
