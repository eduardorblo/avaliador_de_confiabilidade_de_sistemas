# Sistema de Confiabilidade e Disponibilidade em Prolog

## Descrição
Este projeto modela um sistema elétrico simples em Prolog e calcula:
- Confiabilidade e disponibilidade do sistema.
- Taxas equivalentes de falha (λ) considerando topologias em série e paralelo.
- Parâmetros derivados como falhas esperadas e MTTR médio.

O código é recursivo e genérico, permitindo representar circuitos hierárquicos:
- serie([C1, C2, ...])
- paralelo([C3, C4, ...])

## Principais predicados
- component/5 — define um componente com λ (falhas/ano) e MTTR (h).
- topology/2 — descreve a estrutura do sistema.
- reliability_block/3 — calcula confiabilidade por bloco.
- availability_block/2 — calcula disponibilidade por bloco.
- lambda_equivalent_block/3 — obtém a taxa de falhas equivalente.
- system_failure_rate/2 — estima a taxa global do sistema.

## Exemplo de uso (SWI-Prolog)
```
?- [circuit_reliability].
?- reliability_topology(lab_circuit, 8760, R).
?- system_availability_topology(lab_circuit, A).
?- lambda_equivalent_topology(lab_circuit, L).
```

## Requisitos
- SWI-Prolog (https://www.swi-prolog.org/)

## Autor
Material didático voltado ao estudo de **confiabilidade de sistemas elétricos** e **modelagem declarativa**.
