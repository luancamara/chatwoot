# Triagem híbrida para a caixa de WhatsApp

## Contexto

Hoje as novas conversas da caixa de WhatsApp chegam primeiro aos vendedores. Isso cria um conflito de interesse quando o cliente relata uma reclamação, risco de cancelamento ou problema recorrente: o vendedor pode demorar para escalar, tentar tratar um assunto fora de sua responsabilidade ou ocultar a gravidade do caso.

Esta mudança introduz uma recepção automática que direciona o cliente para a área adequada e retira reclamações da fila comercial. O foco principal é acolher um cliente possivelmente frustrado, evitar que ele repita o relato e garantir que um grupo independente conduza o caso até o encerramento.

## Objetivos

- Direcionar novas conversas para Vendas, Financeiro, Pós-venda, Gestão de Reclamações ou Triagem Geral.
- Permitir que o cliente escolha uma área em uma lista interativa do WhatsApp ou escreva livremente.
- Detectar reclamações semanticamente, inclusive depois que a conversa já estiver com outra área.
- Retirar imediatamente a conversa do vendedor quando surgir uma reclamação.
- Fazer com que a Gestão de Reclamações seja responsável pelo caso até o encerramento.
- Informar o encaminhamento ao cliente com uma mensagem curta, fixa e acolhedora.
- Manter o fluxo básico funcionando quando o provedor de IA estiver indisponível.
- Preservar as regras Enterprise de visibilidade já usadas pela instalação.
- Produzir dados auditáveis sobre a origem, gravidade e tempo de tratamento.

## Fora do escopo inicial

- A IA responder perguntas, diagnosticar problemas ou propor soluções ao cliente.
- Bloquear tecnicamente o encerramento por ausência de campos obrigatórios.
- Criar uma interface administrativa completa para configurar a triagem.
- Alterar as regras gerais de visibilidade ou os papéis personalizados Enterprise.
- Substituir a política de SLA já aplicada a uma conversa.
- Classificar canais diferentes da caixa de WhatsApp configurada.

## Abordagens consideradas

### Automações e palavras-chave

Usar apenas regras existentes do Chatwoot exigiria mensagens numeradas em texto ou muitas regras por palavra. É simples de operar, mas não entende contexto, produz falsos positivos e não oferece a melhor experiência para mensagens longas ou indiretas.

### AgentBot externo

Um serviço externo poderia receber webhooks, enviar a lista e chamar a API de atribuição. Essa opção mantém o core isolado, mas adiciona outro deploy, segredo, monitoramento, estado de triagem e ponto de falha.

### Extensão nativa no Enterprise

A solução escolhida adiciona listener, jobs e serviços pequenos no overlay Enterprise. Ela reutiliza o suporte existente a mensagens `input_select`, transcrição, times, autoatribuição, SLA e `Llm::BaseAiService`. Não ativa o Captain como atendente e não depende de outro serviço operacional.

## Experiência do cliente

### Início de um ciclo

Um novo ciclo de triagem começa quando:

- chega a primeira mensagem de uma nova conversa; ou
- chega uma mensagem mais de 24 horas depois do encerramento anterior.

Se o cliente responder dentro de 24 horas após o encerramento, a conversa continua com a equipe anterior. Isso evita pedir novamente uma informação que provavelmente pertence ao mesmo caso. Mesmo sem um novo menu, toda mensagem recebida continua passando pelo detector de reclamações e pode provocar o encaminhamento protegido.

Enquanto a triagem estiver em andamento, a conversa permanece `pending` e sem vendedor por meio de um AgentBot interno, sem webhook externo. A autoatribuição geral da caixa continua habilitada, mas só entra em ação quando o roteador define um time e abre a conversa.

### Ordem de decisão

1. Verificar termos críticos de forma determinística.
2. Reunir mensagens enviadas em sequência durante uma janela curta.
3. Classificar o texto ou a transcrição por IA.
4. Encaminhar diretamente quando houver confiança suficiente.
5. Apresentar o menu quando a classificação não for segura.
6. Encaminhar para Triagem Geral se, depois do menu, o cliente escrever uma nova resposta livre e a IA continuar inconclusiva.

Termos críticos não aguardam a IA. O debounce serve apenas para compreender relatos fragmentados sem fazer várias chamadas nem reagir a cada frase isolada.

### Menu do WhatsApp

Mensagem:

> Olá! Para encaminhar você diretamente à equipe mais adequada, escolha uma opção abaixo. Se preferir, pode escrever com suas próprias palavras.

Itens:

- Comprar ou pedir orçamento
- Pagamentos, boletos ou notas
- Entrega, montagem ou pós-venda
- Tenho um problema ou reclamação
- Outro assunto

Como há mais de três itens, o provedor enviará uma lista interativa do WhatsApp. Os títulos são únicos porque a integração atual recebe a resposta interativa como texto visível.

O menu é enviado no máximo uma vez por ciclo. Uma resposta livre continua válida; o cliente não fica preso em um laço exigindo que pressione uma opção.

### Confirmações de encaminhamento

Para áreas não críticas, o sistema envia uma confirmação curta com o nome amigável da área. Para reclamações, envia no máximo uma confirmação por ciclo.

Durante o horário de atendimento:

> Entendi que você precisa de uma atenção especial. Encaminhei sua conversa para nossa equipe responsável, que dará continuidade ao atendimento por aqui em breve.

Fora do horário de atendimento:

> Recebemos seu relato e o encaminhamos para nossa equipe responsável. O atendimento terá continuidade por aqui no próximo período de atendimento.

Esses textos são configurados e versionados. A IA apenas escolhe a classificação; ela nunca cria, complementa ou reescreve mensagens ao cliente.

## Classificação

### Entrada

O classificador recebe somente o conteúdo público necessário:

- as mensagens recentes do cliente;
- um contexto curto das últimas mensagens públicas da conversa;
- transcrição de áudio, quando disponível.

Notas privadas, tokens, dados de configuração e anexos sem texto não são enviados. Identificadores de contato desnecessários são omitidos.

Áudios usam a transcrição Enterprise existente. O job de triagem aguarda a transcrição por um intervalo limitado; se ela falhar, apresenta o menu em vez de deixar o cliente sem resposta.

### Saída estruturada

O modelo deve responder segundo um esquema fechado equivalente a:

```json
{
  "area": "complaints",
  "severity": "critical",
  "confidence": 0.96,
  "reason": "Cliente relata cancelamento após tentativas anteriores sem solução"
}
```

Valores aceitos:

- `area`: `sales`, `finance`, `after_sales`, `complaints`, `general` ou `unknown`;
- `severity`: `normal`, `complaint` ou `critical`;
- `confidence`: número entre 0 e 1;
- `reason`: justificativa interna curta, sem instruções operacionais.

Qualquer resposta fora do esquema é tratada como falha e leva ao menu ou à Triagem Geral.

### Limiares iniciais

- Reclamação com confiança igual ou superior a 0,70: encaminhar para Gestão de Reclamações.
- Outra área com confiança igual ou superior a 0,85: encaminhar para a área identificada.
- Abaixo do limiar: apresentar o menu.
- Termo crítico inequívoco: encaminhar imediatamente como crítico, independentemente da IA.

Esses valores devem ser configuráveis para ajuste após observar casos reais. Uma reclamação nunca é rebaixada automaticamente durante o mesmo ciclo.

### Sinais críticos iniciais

O conjunto inicial inclui, com variações de escrita e contexto:

- Procon, advogado, processo, ação judicial ou denúncia;
- cobrança indevida ou cobrança repetida sem solução;
- pedido explícito de cancelamento por problema não resolvido;
- produto com defeito acompanhado de recusa ou demora de atendimento;
- ameaça de exposição pública associada a uma reclamação real;
- repetição de que ninguém responde ou resolve.

Palavras isoladas não bastam quando o contexto indicar outro significado. Por exemplo, cancelar um boleto emitido incorretamente não implica automaticamente cancelamento da relação comercial.

## Roteamento e propriedade

### Mapeamento

A configuração associa IDs estáveis aos times:

- Vendas;
- Financeiro;
- Pós-venda;
- Gestão de Reclamações;
- Triagem Geral.

Nenhum nome de pessoa ou ID de time fica fixo na lógica. A configuração também define a caixa habilitada, o responsável de contingência e os limiares.

### Encaminhamento comum

Ao definir uma área, o roteador atualiza a conversa em uma operação consistente:

- remove o responsável incompatível;
- define o time;
- define prioridade e etiquetas;
- atualiza os atributos da triagem;
- permite que a autoatribuição do time escolha um membro disponível.

Se nenhum membro estiver disponível, a conversa é atribuída ao responsável de contingência e uma notificação é enviada ao grupo. O fluxo não deixa uma reclamação sem uma pessoa nominalmente responsável.

### Encaminhamento de reclamações

Uma reclamação detectada em qualquer momento:

- remove explicitamente o vendedor atual;
- atribui o time Gestão de Reclamações;
- marca prioridade alta ou urgente;
- registra a área anterior, a fonte da detecção e a justificativa;
- envia a confirmação fixa ao cliente apenas se ainda não tiver sido enviada;
- notifica a gerência imediatamente quando a gravidade for crítica.

A Gestão de Reclamações responde ao cliente, investiga com outras áreas e mantém a propriedade até a resolução. Consultas a Vendas, Financeiro ou Pós-venda ocorrem por notas privadas, menções ou processos internos, sem devolver informalmente a conversa.

## Estado e idempotência

Os atributos de conversa visíveis à operação incluem:

- `triage_status`;
- `triage_area`;
- `triage_source`;
- `triage_confidence`;
- `triage_started_at`;
- `triage_routed_at`;
- `complaint_severity`;
- `complaint_reason`;
- `complaint_previous_area`;
- `complaint_acknowledged_at`.

Os estados principais são `awaiting_classification`, `awaiting_selection`, `routed` e `complaint_owned`.

Jobs usam a conversa e o ciclo como chave idempotente. Entregas duplicadas do webhook, novas tentativas de job ou várias mensagens em sequência não podem enviar menus repetidos, duplicar confirmações ou devolver uma reclamação para outra área.

## SLA e escalonamento

Configuração inicial sugerida para reclamações:

- primeira resposta humana: 10 minutos;
- próxima resposta enquanto o cliente aguarda: 30 minutos;
- posicionamento conclusivo: 8 horas úteis;
- caso crítico: notificação imediata à gerência.

Se a conversa ainda não tiver SLA, o roteador aplica a política de reclamações. Como o Chatwoot impede trocar uma política já aplicada, uma reclamação detectada posteriormente preserva o SLA existente e inicia um temporizador próprio.

Escalonamento inicial:

1. Ao atingir o primeiro prazo sem resposta, notificar o responsável e o grupo.
2. Persistindo a ausência, notificar e atribuir ao responsável de contingência.
3. Casos críticos notificam a gerência no momento do encaminhamento, sem aguardar prazo.

Os prazos respeitam o horário configurado na caixa. A mensagem ao cliente fora do expediente não promete atendimento imediato.

## Orientação de encerramento

Nesta primeira versão não haverá bloqueio técnico. Uma resposta pronta e uma orientação operacional pedirão que o responsável registre em nota privada:

- tipo e gravidade da reclamação;
- causa identificada;
- providência tomada;
- resultado final;
- responsável pela decisão.

O bloqueio por campos obrigatórios poderá ser adicionado depois que a equipe validar o processo e o vocabulário real dos casos.

## Arquitetura

A implementação no overlay Enterprise será dividida em unidades pequenas:

- listener de mensagens recebidas e mudanças de ciclo;
- job de coordenação com debounce;
- serviço de palavras críticas;
- serviço de classificação estruturada por IA;
- serviço de criação do menu e mensagens fixas;
- roteador de times, prioridade, etiquetas e atributos;
- serviço de notificação e escalonamento;
- configuração da caixa, times, limiares e mensagens.

O listener processa apenas mensagens recebidas da caixa de WhatsApp habilitada. O classificador reutiliza `Llm::BaseAiService` e as configurações `CAPTAIN_OPEN_AI_API_KEY`, `CAPTAIN_OPEN_AI_MODEL` e `CAPTAIN_OPEN_AI_ENDPOINT`, sem conectar um Captain Assistant à caixa.

O processo de configuração cria ou reutiliza um AgentBot interno de triagem e o conecta à caixa. O bot não possui `outgoing_url`; sua função é manter conversas novas ou reabertas em `pending` até a decisão do roteador. Depois da decisão, a conversa é aberta e segue pela autoatribuição normal do time escolhido.

A funcionalidade fica protegida por uma configuração de ativação. Ela pode ser habilitada primeiro em homologação e desligada imediatamente sem rollback de código.

## Observabilidade e privacidade

Devem ser registrados sem expor o conteúdo integral da conversa:

- conversa e ciclo processados;
- resultado e latência da classificação;
- fonte da decisão;
- falhas do provedor;
- mudança de time;
- disparo de confirmação e escalonamento.

As chamadas de IA usam a instrumentação já existente, mas não devem registrar segredos nem notas privadas. A retenção e o tratamento de conteúdo no provedor devem seguir a política contratada pela instalação.

## Relatórios

Os atributos e etiquetas permitirão acompanhar:

- volume por área e origem da classificação;
- reclamações normais e críticas;
- tempo entre detecção e transferência;
- tempo de primeira resposta e violações;
- área e responsável anteriores à reclamação;
- cancelamentos e resultados;
- reincidência por contato ou motivo;
- classificações de baixa confiança e correções manuais.

## Implantação

1. Criar ou validar os cinco times e seus membros.
2. Definir o grupo Gestão de Reclamações e o responsável de contingência.
3. Criar atributos, etiquetas e política de SLA.
4. Ativar e validar a transcrição de áudio.
5. Validar as credenciais de IA em homologação.
6. Habilitar a triagem somente na caixa de homologação.
7. Executar os cenários de aceitação.
8. Treinar o grupo responsável e publicar a orientação de encerramento.
9. Habilitar a caixa de produção com monitoramento próximo.
10. Revisar falsos positivos, falsos negativos e prazos após a primeira semana.

## Cenários de aceitação

- Cliente escreve apenas “olá” e recebe um único menu.
- Cliente escolhe Vendas e é encaminhado ao time correto.
- Cliente escolhe Reclamações e recebe a confirmação acolhedora.
- Cliente descreve uma reclamação sem usar a palavra “reclamação” e é encaminhado pela IA.
- Cliente já atendido por vendedor relata um problema; o vendedor é removido e a Gestão de Reclamações assume.
- Cliente envia várias mensagens curtas; ocorre uma única classificação e uma única confirmação.
- Cliente envia áudio; a transcrição é usada na classificação.
- Provedor de IA falha; termos críticos e menu continuam funcionando.
- Cliente responde fora do horário; recebe a versão correta da confirmação.
- Cliente responde em até 24 horas após encerramento; não recebe novo menu.
- Cliente retorna depois de 24 horas; inicia um novo ciclo.
- Entrega duplicada de evento não duplica mensagens nem atribuições.
- Reclamação classificada não é rebaixada automaticamente.
- Vendedor deixa de visualizar a conversa após a transferência, conforme o papel Enterprise vigente.
- Caso sem agente disponível alerta o grupo e o responsável de contingência.

## Critérios de sucesso

- Nenhuma reclamação identificada permanece atribuída a vendedor.
- Cliente recebe confirmação imediata e não precisa repetir o relato para iniciar a tratativa.
- Falha da IA não impede o acesso ao atendimento humano.
- Menus e confirmações não são duplicados.
- Gestão de Reclamações mantém propriedade até o encerramento.
- A operação consegue auditar por que e quando cada transferência aconteceu.
