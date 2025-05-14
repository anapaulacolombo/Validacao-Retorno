--ALTER SESSION SET CURRENT_SCHEMA=SANKHYA;
                       
CREATE OR REPLACE PROCEDURE AD_STP_VALIDA_DIVERGENCIA (
       P_CODEMP   NUMBER,
       P_CODPARC   NUMBER,
       P_NUNOTA    NUMBER,        -- Código do usuário logado
       P_CODPROD   NUMBER,        -- Identificador da execução. Serve para buscar informações dos parâmetros/campos da execução.
       P_SEQ       NUMBER,        -- Informa a quantidade de registros selecionados no momento da execução.
       P_LOCAL     NUMBER,
       P_LOTE      VARCHAR2,
       P_TEMDIV    OUT VARCHAR2    -- Caso seja passada uma mensagem aqui, ela será exibida como uma informação ao usuário.
) AS
       V_TIPMOV         VARCHAR(10);
       V_NUNOTA         TGFCAB.NUNOTA%TYPE;
       V_TEMRASTROLOTE  TGFPRO.TEMRASTROLOTE%TYPE;
       V_QUANTIDADE     TGFITE.QTDNEG%TYPE;
       V_CONTROLE       TGFITE.CONTROLE%tYPE;
       V_CODLOCALORIG   TGFITE.CODLOCALORIG%TYPE;
       V_CODEMP         TGFCAB.CODEMP%TYPE;
       V_CODPARC        TGFCAB.CODPARC%TYPE;
       V_DESCRPROD      TGFPRO.DESCRPROD%TYPE;
       V_CODTIPOPER     TGFCAB.CODTIPOPER%TYPE;
       V_ESTQTERC       TGFTOP.ATUALESTTERC%TYPE;
       V_AD_TOPVALRET   TGFTOP.AD_TOPVALRET%tYPE;
       V_ESTOQUE        TGFEST.ESTOQUE%TYPE;
       V_CODPROD        TGFITE.CODPROD%TYPE;
       V_RESERVADO      TGFEST.ESTOQUE%TYPE;
       V_SALDO          TGFEST.ESTOQUE%TYPE;
       V_CODVOL         TGFITE.CODVOL%TYPE;
       V_CONT           INTEGER;

BEGIN

/************************************************************************************************************
-- Task [Logistica] PE2.48 - Validar Vencimento e Lote Inativo na rotina de transferencia entre locais
https://grupoboticario.kanbanize.com/ctrl_board/301/cards/1188425/details/

---Criado por Ana Paula Colombo em 25/02/25
-- Objetivo:  Não permitir retornar produtos sem saldo de remessa ou de lotes que não foram enviados
-- Nesta trigger não permite alterar a quantidade em notas de retorno
*************************************************************************************************************/
           V_SALDO:= 0;

           SELECT TGFPRO.TEMRASTROLOTE INTO V_TEMRASTROLOTE
           FROM TGFPRO
           WHERE CODPROD = P_CODPROD;


           IF V_TEMRASTROLOTE = 'S' THEN
                       -- VERIFICA SE HÁ ESTOQUE DE TERCEIRO DO PRODUTO, LOCAL, CONTROLE E PARCEIRO INFORMADO
                        SELECT NVL(SUM(ESTOQUE ),0), NVL(SUM(RESERVADO),0)
                          INTO V_ESTOQUE , V_RESERVADO
                        FROM TGFEST EST
                        WHERE EST.CODEMP  = P_CODEMP
                        AND   EST.CODPARC = P_CODPARC
                        AND   EST.CODPROD = P_CODPROD
                        AND   EST.CONTROLE = P_LOTE
                        AND   EST.CODLOCAL = P_LOCAL;
          ELSE
                        SELECT NVL(SUM(ESTOQUE ),0), NVL(SUM(RESERVADO),0)
                          INTO V_ESTOQUE , V_RESERVADO
                        FROM TGFEST EST
                        WHERE EST.CODEMP  = P_CODEMP
                        AND   EST.CODPARC = P_CODPARC
                        AND   EST.CODPROD = P_CODPROD
                        AND   EST.CODLOCAL = P_LOCAL;

         END IF;
         -- Calcula o saldo disponivel
         IF V_ESTOQUE > V_RESERVADO THEN
                        V_SALDO := V_ESTOQUE - V_RESERVADO;
         ELSE
                         V_SALDO :=  V_ESTOQUE ;
         END IF;

        -- SE NÃO HOUVER LINHA TGFEST SIGNIFICA QUE NÃO HÁ SALDO PARA DEVOLVER
         IF ((V_SALDO = 0 ) OR (V_SALDO < 0) or (V_SALDO < V_QUANTIDADE)) THEN
                           
            P_TEMDIV:= 'S';
        ELSE
                      
           P_TEMDIV:= 'N';                    
       END IF;

END;
