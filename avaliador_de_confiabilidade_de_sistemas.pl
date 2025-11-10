% circuit_reliability.pl (refatorado - ordem didática)
% Projeto didático: confiabilidade e disponibilidade de um circuito eletrônico simples
% Estrutura: system -> circuit -> component -> topology
% Ordem das seções: fatos, helpers, confiabilidade (componente), confiabilidade (bloco),
% lambda equivalente (usa confiabilidade do bloco), disponibilidade, CTMC, exemplos.

% ---------------------------------------------------------------------
% Base de dados (exemplo simples: lab_circuit)
% ---------------------------------------------------------------------
system(lab_circuit).
circuit(lab_circuit, main_stage).

% component(Name, Circuit, Type, Lambda_per_year, MTTR_hours)
% Os componentes podem ser acrescidos e alterados segundo a MIL-HDBK-217F.
% link para consulta: https://www.quanterion.com/wp-content/uploads/2014/09/MIL-HDBK-217F.pdf?srsltid=AfmBOor_DY5zl3P9ZAK1ne6p65tFm4pkkF_sqRV06Xwqe9cHmzrmCN1r
component(v,  main_stage, source,   0.3  ,  3 ).     
component(r1,     main_stage, resistor,  0.03,  2).
component(r2,     main_stage, resistor,  0.03,  2). 

% representação da topologia do circuito exemplo. Deve ser modificada segundo as alterações dos componentes.
topology(lab_circuit,
    serie([
        v,
        paralelo([v, r1]),
        r2
    ])
).

% ---------------------------------------------------------------------
% HELPERS (operações sobre listas)
% ---------------------------------------------------------------------
product_list(List, Prod) :-
    product_list_acc(List, 1.0, Prod).
product_list_acc([], Acc, Acc).
product_list_acc([H|T], Acc, Prod) :-
    Acc1 is Acc * H,
    product_list_acc(T, Acc1, Prod).

sum_list(Ls, Sum) :-
    sum_list_acc(Ls, 0.0, Sum).
sum_list_acc([], Acc, Acc).
sum_list_acc([H|T], Acc, Sum) :-
    Acc1 is Acc + H,
    sum_list_acc(T, Acc1, Sum).

invert_list([], []).
invert_list([H|T], [I|Is]) :-
    I is 1.0 - H,
    invert_list(T, Is).

% ---------------------------------------------------------------------
% CONSULTAS SOBRE ESTRUTURA
% ---------------------------------------------------------------------
% Lista componentes pertencentes a um sistema (via circuit/2)
components_of_system(System, Components) :-
    findall(Name, (circuit(System, C), component(Name, C, _, _, _)), Components).

components_of_circuit(Circuit, Comps) :-
    findall(Name, component(Name, Circuit, _, _, _), Comps).

component_lambda(Name, Lambda) :-
    component(Name, _, _, Lambda, _).

% ---------------------------------------------------------------------
% CONFIABILIDADE DE COMPONENTE (modelo exponencial)
% ---------------------------------------------------------------------
% component_reliability(+Name, +Hours, -R)
% R(t) = exp(-lambda * t_years)
component_reliability(Name, Hours, R) :-
    component(Name, _, _, Lambda, _),
    Tyears is Hours / 8760.0,
    Exponent is - Lambda * Tyears,
    R is exp(Exponent).

% ---------------------------------------------------------------------
% CONFIABILIDADE DE BLOCOS (recursivo: serie/1, paralelo/1, átomo)
% ---------------------------------------------------------------------

% reliability_list(+Elements, +Hours, -Rs)
reliability_list([], _Hours, []).
reliability_list([E|Es], Hours, [R|Rs]) :-
    reliability_block(E, Hours, R),
    reliability_list(Es, Hours, Rs).

% reliability_block(+Block, +Hours, -R)
% Block pode ser: serie(List), paralelo(List), ou átomo (nome do componente)

reliability_block(serie(Elements), Hours, R) :-
    reliability_list(Elements, Hours, Rs),
    product_list(Rs, R).

reliability_block(paralelo(Elements), Hours, R) :-
    reliability_list(Elements, Hours, Rs),
    invert_list(Rs, OnesMinus),
    product_list(OnesMinus, ProdInv),
    R is 1.0 - ProdInv.

reliability_block(Component, Hours, R) :-
    atom(Component),
    component_reliability(Component, Hours, R).

% confiabilidade do bloco sistema
reliability_topology(System, Hours, R) :-
    topology(System, Topo),
    reliability_block(Topo, Hours, R).

% ---------------------------------------------------------------------
% LAMBDA EQUIVALENTE (USANDO R DO BLOCO)
% ---------------------------------------------------------------------
% lambda_equivalent_block(+Block, +Hours, -LambdaEq)
% Calcula a taxa equivalente em falhas/ano do bloco para o intervalo Hours.
% Definição: LambdaEq = - ln(R_block) / Tyears, com tratamento de casos extremos.
lambda_equivalent_block(Block, Hours, LambdaEq) :-
    % calculamos Rblock como confiabilidade do bloco no intervalo Hours
    (   catch(reliability_block(Block, Hours, Rblock), _, fail)
    ->  true
    ;   Rblock = 1.0
    ),
    Tyears is Hours / 8760.0,
    (   Rblock =< 0.0
    ->  LambdaEq is 1.0e12           % sinaliza praticamente infinito
    ;   Rblock =:= 1.0
    ->  LambdaEq is 0.0
    ;   LambdaEq is - log(Rblock) / Tyears
    ).

% lambda equivalente do bloco raiz (topologia do sistema), em falhas/ano
lambda_equivalent_topology(System, LambdaPerYear) :-
    topology(System, Topo),
    lambda_equivalent_block(Topo, 8760, LambdaPerYear).

% Campo de controle
system_failure_rate(System, LambdaSum) :-
    lambda_equivalent_topology(System, LambdaSum).

% homônimo de consulta
expected_failures_per_year(System, Expected) :-
    system_failure_rate(System, Expected).

% ---------------------------------------------------------------------
% DISPONIBILIDADE (estacionária, 2-estado) - aplicada por bloco
% ---------------------------------------------------------------------
% component_availability(+Name, -Avail)
component_availability(Name, Avail) :-
    component(Name, _, _, Lambda, MTTR_hours),
    MTTR_years is MTTR_hours / 8760.0,
    (  MTTR_years =:= 0.0 ->
       Avail = 0.0
    ;  Mu is 1.0 / MTTR_years,
       Avail is Mu / (Lambda + Mu)
    ).

% availability_list(+Elements, -As)
% Percorre a lista de elementos de um bloco e calcula A usando availability_block/2
availability_list([], []).
availability_list([E|Es], [A|As]) :-
    availability_block(E, A),
    availability_list(Es, As).

% availability_block(+Block, -A)
availability_block(serie(Elements), A) :-
    availability_list(Elements, As),
    product_list(As, A).

availability_block(paralelo(Elements), A) :-
    availability_list(Elements, As),
    invert_list(As, Inv),
    product_list(Inv, ProdInv),
    A is 1.0 - ProdInv.

availability_block(Component, A) :-
    atom(Component),
    component_availability(Component, A).

% retorna a resultante do sistema completo
% system_availability(+System, -A_sys)
system_availability_topology(System, A_sys) :-
    topology(System, Topo),
    availability_block(Topo, A_sys).

% ---------------------------------------------------------------------
% CTMC transiente (2 estados) - componente isolado
% ---------------------------------------------------------------------
ctmc_transient(Name, Hours, P_up, P_down) :-
    component(Name, _, _, Lambda, MTTR_hours),
    MTTR_years is MTTR_hours / 8760.0,
    ( MTTR_years =:= 0.0 -> Mu = 0.0 ; Mu is 1.0 / MTTR_years ),
    T is Hours / 8760.0,
    SumRates is Lambda + Mu,
    ( SumRates =:= 0.0 ->
        P_up = 1.0, P_down = 0.0
    ;
        P_up_stat is Mu / SumRates,
        P_up is P_up_stat + (Lambda / SumRates) * exp(- SumRates * T),
        P_down is 1.0 - P_up
    ).

% ---------------------------------------------------------------------
% Exemplos de consultas
% ---------------------------------------------------------------------
% ?- components_of_system(lab_circuit, C).
% ?- reliability_topology(lab_circuit, 24, R24).
% ?- reliability_topology(lab_circuit, 8760, R1year).
% ?- lambda_equivalent_topology(lab_circuit, LambdaPerYear).
% ?- system_failure_rate(lab_circuit, Lambda).
% ?- expected_failures_per_year(lab_circuit, E).
% ?- component_availability(v_src, Av).
% ?- system_availability_topology(lab_circuit, A).
% ?- ctmc_transient(v_src, 48, Pup, Pdown).
%
% ---------------------------------------------------------------------
% Fim
% ---------------------------------------------------------------------
