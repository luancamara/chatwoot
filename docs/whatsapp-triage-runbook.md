# Operação da triagem do WhatsApp

## Pré-requisitos

- Licença Enterprise ativa.
- Caixa com `Channel::Whatsapp`.
- Credenciais `CAPTAIN_OPEN_AI_API_KEY`, `CAPTAIN_OPEN_AI_MODEL` e, se necessário, `CAPTAIN_OPEN_AI_ENDPOINT` configuradas.
- Times Vendas, Financeiro, Pós-venda, Gestão de Reclamações e Triagem Geral.
- Um responsável de contingência que pertença a cada time e também à caixa.
- O time Gestão de Reclamações deve ser diferente de todos os demais.

## Localizar IDs

Inicialize o `rbenv` antes dos comandos Ruby:

```sh
eval "$(rbenv init -)"
bundle exec rails runner '
Inbox.where(channel_type: "Channel::Whatsapp").find_each { |inbox| puts "INBOX #{inbox.id}: #{inbox.name}" }
Team.find_each { |team| puts "TEAM #{team.id}: #{team.name}" }
User.find_each { |user| puts "USER #{user.id}: #{user.name}" }
SlaPolicy.find_each { |sla| puts "SLA #{sla.id}: #{sla.name}" }
'
```

## Criar a configuração

Garanta que o registro de configuração exista:

```sh
eval "$(rbenv init -)"
bundle exec rails runner 'ConfigLoader.new.process'
```

No Super Admin, abra `/super_admin/app_config?config=whatsapp_triage`, edite `WHATSAPP_TRIAGE_CONFIG` e substitua todo o conteúdo por JSON válido com os IDs reais:

```json
{
  "enabled": false,
  "inbox_id": 1,
  "team_ids": {
    "sales": 10,
    "finance": 11,
    "after_sales": 12,
    "complaints": 13,
    "general": 14
  },
  "fallback_user_ids": {
    "sales": 100,
    "finance": 101,
    "after_sales": 102,
    "complaints": 103,
    "general": 104
  },
  "sla_policy_id": 20,
  "debounce_seconds": 4,
  "reopen_window_hours": 24,
  "complaint_threshold": 0.7,
  "area_threshold": 0.85,
  "first_response_minutes": 10,
  "next_response_minutes": 30,
  "resolution_minutes": 480,
  "menu_message": "Olá! Para encaminhar você diretamente à equipe mais adequada, escolha uma opção abaixo. Se preferir, pode escrever com suas próprias palavras.",
  "complaint_acknowledgement": "Entendi que você precisa de uma atenção especial. Encaminhei sua conversa para nossa equipe responsável, que dará continuidade ao atendimento por aqui em breve.",
  "complaint_acknowledgement_out_of_office": "Recebemos seu relato e o encaminhamos para nossa equipe responsável. O atendimento terá continuidade por aqui no próximo período de atendimento.",
  "out_of_office_message": "Recebemos sua mensagem. Nossa triagem encaminhará o atendimento para a equipe responsável, que dará continuidade por aqui no próximo período de atendimento.",
  "routing_acknowledgements": {
    "sales": "Certo! Encaminhei sua conversa para nossa equipe de vendas.",
    "finance": "Certo! Encaminhei sua conversa para nossa equipe financeira.",
    "after_sales": "Certo! Encaminhei sua conversa para nossa equipe de pós-venda.",
    "general": "Certo! Encaminhei sua conversa para nossa equipe de atendimento."
  }
}
```

O `sla_policy_id` pode ser `null`. Os demais IDs são obrigatórios. O valor é mantido como JSON depois da primeira ativação para facilitar revisões futuras no mesmo editor.

## Preparar e ativar

O comando abaixo valida todos os relacionamentos, cria atributos e etiquetas, ativa transcrição de áudio, conecta o AgentBot interno e habilita a triagem:

```sh
eval "$(rbenv init -)"
bundle exec rails whatsapp_triage:enable
```

Ele também desativa a saudação antiga da caixa e configura uma mensagem neutra para fora do expediente, evitando mensagens automáticas redundantes.

Consulte o estado sem mostrar credenciais:

```sh
eval "$(rbenv init -)"
bundle exec rails whatsapp_triage:status
```

O campo `Operational` somente aparece como `true` quando a caixa, os times, os responsáveis, as mensagens e o SLA opcional continuam válidos. Se a configuração for alterada incorretamente, novas conversas seguem pelo fluxo normal em vez de ficarem presas na triagem.

## Desligamento seguro

```sh
eval "$(rbenv init -)"
bundle exec rails whatsapp_triage:disable
```

O AgentBot interno permanece conectado, mas o listener abre imediatamente novas conversas para a autoatribuição normal. Assim, desligar a classificação não prende clientes em `pending`.

## Homologação mínima

Antes da produção, valide:

- “Olá” produz uma única lista.
- Cada item encaminha ao time esperado.
- “Ninguém resolve meu problema” vai imediatamente para Gestão de Reclamações.
- “Preciso cancelar um boleto emitido errado” não é tratado como cancelamento crítico.
- Uma reclamação durante atendimento de Vendas remove o vendedor.
- Transferência manual para fora de Gestão de Reclamações é recusada enquanto o caso está aberto.
- Áudio com reclamação é transcrito e classificado.
- Falha temporária da IA ainda permite usar o menu.
- Fora do expediente não há mensagens automáticas redundantes.
- `whatsapp_triage:disable` devolve a caixa ao fluxo normal.
