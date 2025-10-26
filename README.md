```markdown
# 🏛️ Votações do Congresso  
**Transparência parlamentar com dados abertos + análise social com IA livre**  
Projeto desenvolvido por **Leandro Pereira Rodrigues** · 2025  

---

## 📖 Visão Geral

O projeto **Votações do Congresso** é uma plataforma aberta que consulta em tempo real os dados oficiais da Câmara dos Deputados e do Senado Federal (APIs públicas) para exibir de forma simples e direta **como cada parlamentar vota**.  

A ideia é democratizar o acesso à informação política, permitindo que qualquer cidadão visualize, compare e **entenda o impacto das votações legislativas** — tudo com uma camada de **análise automatizada por IA livre**, que traduz o jargão legislativo para linguagem popular, pronta para compartilhamento nas redes sociais (Instagram, X, Facebook).

---

## ⚙️ Arquitetura do Projeto

### 🧱 Frontend
- Framework: **Vite + TypeScript + React**
- Estrutura modular: `src/pages/`, `src/lib/api-camara.ts`, `src/components/`
- Busca instantânea de parlamentares
- Página individual para cada deputado/senador
- Exibição de votações recentes, proposições e ementas

### ☁️ Infraestrutura AWS
- **Amazon S3**: Hospeda o site estático  
  - Bucket: `votacoes-congresso-site-<account-id>`  
  - Configurado com *Static Website Hosting* + *Public Read Policy*
- **CloudFront**: CDN global para HTTPS e cache otimizado  
  - SSL/TLS (v1.2)
  - Compressão GZIP/Brotli automática
  - Index document: `index.html`
- **deploy.sh**: script automatizado de build e deploy  
  - Builda o site (`npm run build`)  
  - Publica no S3  
  - Cria/atualiza a distribuição CloudFront automaticamente  

---

## 🧠 Fontes de Dados

### Câmara dos Deputados
- Base: `https://dadosabertos.camara.leg.br/api/v2/`
- Endpoints usados:
  - `/deputados?nome=`
  - `/deputados/{id}`
  - `/votacoes`
  - `/votacoes/{id}/votos`
  - `/proposicoes?idDeputadoAutor=`

### Senado Federal *(em desenvolvimento)*
- Base: `https://legis.senado.leg.br/dadosabertos/`
- Prevista integração com `/senador/` e `/votacao/`

---

## 💡 Funcionalidades da Versão 1

✅ Busca dinâmica de parlamentares  
✅ Exibição de foto, nome, partido e estado  
✅ Perfil detalhado com email oficial e gabinete  
✅ Listagem de proposições (emendas, requerimentos etc.)  
✅ Identificação automática do voto do deputado em cada sessão  
✅ Deploy automático via `deploy.sh`  
✅ Integração completa com **AWS S3 + CloudFront**

---

## 🧩 Estrutura do Projeto

```

votacoes-congresso/
│
├── src/
│   ├── lib/
│   │   └── api-camara.ts        # Lógica de consumo da API oficial
│   ├── pages/
│   │   ├── Home.tsx             # Busca de deputados
│   │   ├── Deputado.tsx         # Página individual com votações
│   │   └── Senador.tsx          # (planejado)
│   └── components/              # Componentes reutilizáveis
│
├── public/                      # Arquivos estáticos
├── dist/                        # Build gerado pelo Vite
├── deploy.sh                    # Script automatizado AWS
├── package.json
└── README.md

````

---

## 🚀 Deploy

### 1. Build local
```bash
npm install
npm run build
````

### 2. Publicar na AWS

```bash
bash deploy.sh
```

O script automaticamente:

* Verifica/cria o bucket
* Publica os arquivos no S3
* Cria a distribuição CloudFront se não existir
* Exibe as URLs finais do site (HTTP e HTTPS)

---

## 🔐 Permissões Recomendadas (IAM)

Crie uma política mínima para o usuário/deploy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    { "Effect": "Allow", "Action": "s3:*", "Resource": ["arn:aws:s3:::votacoes-congresso-site-*", "arn:aws:s3:::votacoes-congresso-site-*/*"] },
    { "Effect": "Allow", "Action": "cloudfront:*", "Resource": "*" }
  ]
}
```

---

## 🧠 Próximas Etapas (Roadmap)

| Fase                    | Descrição                                                                      | Status |
| ----------------------- | ------------------------------------------------------------------------------ | ------ |
| 📊 IA Popular           | Tradução das votações para linguagem acessível e memes políticos automatizados | 🔜     |
| 🏛️ Senado              | Integração com API do Senado Federal                                           | 🔜     |
| 📱 Postagem automática  | Integração com Instagram/X/Facebook via API                                    | 🔜     |
| 💬 Comentários públicos | Espaço de feedback direto do cidadão                                           | 🔜     |
| 🧾 Exportação CSV       | Permitir baixar planilhas de votações                                          | 🕓     |
| 💰 Custo otimizado      | Automatizar deploy com Lambda + EventBridge                                    | 🕓     |

---

## 🤝 Contribuição

Contribuições são bem-vindas!

1. Faça um fork
2. Crie uma branch: `git checkout -b feature/nova-funcionalidade`
3. Commit suas mudanças: `git commit -m "feat: adiciona nova feature"`
4. Faça push: `git push origin feature/nova-funcionalidade`
5. Abra um Pull Request 🎉

---

## 🧑‍💻 Autor

**Leandro Pereira Rodrigues**
🔹 GitHub: [leandroald](https://github.com/leandroald)
🔹 E-mail: [leandro.ald@gmail.com](mailto:leandro.ald@gmail.com)
🔹 Frase pessoal: *“O resultado é uma metamorfose.”*

---

## ⚖️ Licença

Distribuído sob a licença MIT.
Você pode usar, modificar e distribuir o código, desde que mantenha o crédito ao autor original.

````
