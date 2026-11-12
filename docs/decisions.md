# Decisões técnicas

- SPEC prevalece sobre o guia, inclusive nas lacunas de produto.
- SQL explícito pelo Drift evita geração de código para uma única tabela; detalhes e consequências em [database.md](database.md).
- Projeto vazio por nome é o único fluxo de F1 antecipado, para validar persistência.
- Rotas futuras exibem indisponibilidade explícita; indicadores não são simulados.
- Não há migração destrutiva nem backup automático. Android desabilita backup do sistema.
- Dependências e launchers aguardam validação, conforme [auditoria](audits/f0-foundation-validation.md).
